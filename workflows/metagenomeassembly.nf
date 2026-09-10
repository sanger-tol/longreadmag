/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'
include { ASSEMBLY               } from '../subworkflows/local/assembly'
include { ASSEMBLY_ANALYSIS      } from '../subworkflows/local/assembly_analysis'
include { BINNING                } from '../subworkflows/local/binning'
// include { BIN_QC                 } from '../subworkflows/local/bin_qc'
// include { BIN_TAXONOMY           } from '../subworkflows/local/bin_taxonomy'
include { BINNING_PREPARATION    } from '../subworkflows/local/binning_preparation'
// include { BIN_REFINEMENT         } from '../subworkflows/local/bin_refinement'

include { BIN_SUMMARY            } from '../modules/local/bin_summary'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METAGENOMEASSEMBLY {
    take:
    ch_long_reads_assembly
    ch_hic_reads
    ch_genomad_db
    ch_rfam_rrna_cm
    ch_centrifuger_db
    ch_checkm2_db
    ch_gtdbtk_db
    ch_gtdb_ar53_metadata
    ch_gtdb_bac120_metadata
    val_pipeline_stages
    val_assembler
    val_contig_filters
    val_binners
    val_bin_refiners
    val_tools
    val_alignment_options
    outdir

    main:
    ch_versions = channel.empty()

    ch_long_reads = ch_long_reads_assembly.map { meta, reads, _assembly ->
        [meta - meta.subMap("assembler"), reads]
    }

    //
    // Subworkflow: Assemble PacBio hifi reads
    //
    ASSEMBLY(
        ch_long_reads_assembly,
        val_assembler,
        val_binners,
    )

    ASSEMBLY_ANALYSIS(
        ASSEMBLY.out.assemblies,
        ASSEMBLY.out.concatenated_assemblies,
        ch_genomad_db,
        val_tools.enable_tiara,
        val_tools.enable_genomad,
    )

    if (val_pipeline_stages.enable_binning) {
        //
        // Subworkflow: Map PacBio Hifi reads and Illumina Hi-C
        // reads to the assembly and estimate per-contig coverages
        //
        BINNING_PREPARATION(
            ASSEMBLY.out.assemblies,
            ASSEMBLY.out.concatenated_assemblies,
            ch_long_reads,
            ch_hic_reads,
            ASSEMBLY_ANALYSIS.out.tiara_classifications,
            val_binners,
            val_alignment_options,
            val_contig_filters,
        )


        //
        // Subworkflow: Bin the assembly using binning tools
        //
        // BINNING(
        //     BINNING_PREPARATION.out.filtered_assembly,
        //     BINNING_PREPARATION.out.circles,
        //     BINNING_PREPARATION.out.depths,
        //     BINNING_PREPARATION.out.filtered_bam,
        //     BINNING_PREPARATION.out.hic_pairs,
        //     ch_centrifuger_db,
        //     val_binners,
        // )
        // ch_bins = BINNING.out.bins
        // ch_contig2bin = BINNING.out.contig2bin
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'metagenomeassembly_software_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    emit:
    versions = ch_versions // channel: [ path(versions.yml) ]
}
