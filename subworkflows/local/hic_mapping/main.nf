include { PAIRTOOLS_PARSESORTFILTER } from '../../../modules/local/pairtools/parsesortfilter'
include { SAMTOOLS_FAIDX            } from '../../../modules/nf-core/samtools/faidx'

include { CRAM_MAP_ILLUMINA_HIC     } from '../../../subworkflows/sanger-tol/cram_map_illumina_hic'

workflow HIC_MAPPING {
    take:
    ch_assemblies
    ch_hic_reads
    ch_filter_list
    val_mapping_options

    main:
    //
    // Subworkflow: run chunked hi-c mapping
    //
    ch_hic_mapping_inputs = ch_assemblies
        .combine(ch_hic_reads, by: 0)
        .multiMap { meta, asm, cram ->
            assemblies: [meta, asm]
            cram: [meta, cram]
        }

    //
    // Logic: Index input assemblies to get chromsizes
    //
    SAMTOOLS_FAIDX(
        ch_assemblies.map { meta, asm -> [meta, asm, []] },
        true,
    )

    CRAM_MAP_ILLUMINA_HIC(
        ch_hic_mapping_inputs.assemblies,
        ch_hic_mapping_inputs.cram,
        val_mapping_options.hic_aligner,
        val_mapping_options.hic_mapping_cram_slices_per_chunk,
    )

    //
    // Module: Parse BAM into pairs format
    //
    ch_pairtools_parse_input = CRAM_MAP_ILLUMINA_HIC.out.bam
        .combine(SAMTOOLS_FAIDX.out.sizes, by: 0)
        .join(ch_filter_list, by: 0, remainder: true)

    PAIRTOOLS_PARSESORTFILTER(ch_pairtools_parse_input)

    emit:
    bam   = CRAM_MAP_ILLUMINA_HIC.out.bam
    pairs = PAIRTOOLS_PARSESORTFILTER.out.pairs
}
