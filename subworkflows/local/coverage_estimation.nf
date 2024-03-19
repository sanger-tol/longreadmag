#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { MINIMAP2_ALIGN                       } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_FAIDX                       } from '../modules/nf-core/samtools/faidx/main' 
include { SAMTOOLS_SORT                        } from '../modules/nf-core/samtools/sort/main' 
include { SAMTOOLS_VIEW                        } from '../modules/nf-core/samtools/view/main'
include { METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS } from '../modules/nf-core/metabat2/jgisummarizebamcontigdepths/main'


workflow COVERAGE_ESTIMATION {

    take:
    reference_ch        // Channel: tuple [ val(meta), file( reference_file ) ]
    dot_genome          // Channel: tuple [ val(meta), [ file( datafile ) ]   ]
    read_ch             // Channel: tuple [ val(meta), val( str )             ]  read channel (.fasta.gz)

    main:
    ch_versions                 = Channel.empty()

    //
    // MODULE: GENERATE REF INDEX
    //
    SAMTOOLS_FAIDX(
        reference_ch
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    //
    // LOGIC: PREPARE FOR MINIMAP2, USING READ_TYPE AS FILTER TO DEFINE THE MAPPING METHOD, CHECK YAML_INPUT.NF
    //
    reference_ch
        .combine( ch_reads_path )
        .combine( read_ch)
        .map { meta, ref, reads_path, read_meta, readfolder ->
            tuple(
                [   id          : meta.id,
                    single_end  : read_meta.single_end,
                    readtype    : read_meta.read_type.toString()
                ],
                reads_path,
                ref,
                true,
                false,
                false,
                read_meta.read_type.toString()
            )
        }
        .set { pre_minimap_input }

    pre_minimap_input
        .multiMap { meta, reads_path, ref, bam_output, cigar_paf, cigar_bam, reads_type ->
            read_tuple          : tuple( meta, reads_path)
            ref                 : ref
            bool_bam_ouput      : bam_output
            bool_cigar_paf      : cigar_paf
            bool_cigar_bam      : cigar_bam
        }
        .set { minimap_input }


    //
    // PROCESS: USING MINIMAP2, MAP READS TO ASSEMBLY
    //
    MINIMAP2_ALIGN (
            minimap_input.read_tuple,
            minimap_input.ref,
            minimap_input.bool_bam_ouput,
            minimap_input.bool_cigar_paf,
            minimap_input.bool_cigar_bam
    )
    ch_versions                 = ch_versions.mix(MINIMAP2_ALIGN.out.versions)
    ch_bams                     = MINIMAP2_ALIGN.out.bam

    //
    // MODULE: SORT BAM
    //
    SAMTOOLS_VIEW (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix( SAMTOOLS_VIEW.out.versions )

    //
    // MODULE: SORT BAM
    //
    SAMTOOLS_SORT (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix( SAMTOOLS_SORT.out.versions )

    //
    // MODULE: CALCULATING CONTIG READ DEPTHS USING METABAT2
    //
    METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix( METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS.out.versions )

    emit:
    ch_depth            = METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS.out.depth
    versions                = ch_versions


}