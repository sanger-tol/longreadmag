include { FILTER_ASSEMBLY   } from '../../../modules/local/filter_assembly'
include { COVERM_CONTIG     } from '../../../modules/nf-core/coverm/contig'

include { LONG_READ_MAPPING } from '../../../subworkflows/local/long_read_mapping'
include { HIC_MAPPING       } from '../../../subworkflows/local/hic_mapping'

workflow BINNING_PREPARATION {
    take:
    ch_assemblies
    ch_concatenated_assemblies
    ch_long_reads
    ch_hic_reads
    ch_tiara_classifications
    val_binners
    val_mapping_options
    val_contig_filters

    main:
    //
    // Module: Filter the assembled contigs to remove circles (if requested), as well
    // as too-large or too-small contigs. If tiara was run, it can also be used to
    // filter the assembly.
    //
    ch_filter_assembly_input = ch_assemblies
        .mix(ch_concatenated_assemblies)
        .join(ch_tiara_classifications)

    FILTER_ASSEMBLY(
        ch_filter_assembly_input,
        val_contig_filters.minimum_contig_size ?: [],
        val_contig_filters.maximum_contig_size ?: [],
        val_binners.circular,
        val_contig_filters.minimum_circular_contig_length ?: [],
        val_contig_filters.tiara_exclude_classifications?.split(",") ?: [],
    )

    //
    // Subworkflow: run chunked hi-c mapping
    //
    HIC_MAPPING(
        ch_assemblies.filter { val_binners.metator },
        ch_hic_reads,
        FILTER_ASSEMBLY.out.filter_list,
        val_mapping_options,
    )

    //
    // Subworkflow: Long read mapping
    //
    LONG_READ_MAPPING(
        ch_assemblies,
        ch_long_reads,
        FILTER_ASSEMBLY.out.filter_list,
        val_mapping_options,
    )

    //
    // Module: Calculate per-contig coverage using coverm
    //
    COVERM_CONTIG(
        LONG_READ_MAPPING.out.filtered_bam,
        [[], []],
        true,
        false,
        false,
    )

    emit:
    filtered_assembly = FILTER_ASSEMBLY.out.filtered
    circles           = FILTER_ASSEMBLY.out.circles
    full_bam          = LONG_READ_MAPPING.out.bam
    filtered_bam      = LONG_READ_MAPPING.out.filtered_bam
    hic_bam           = HIC_MAPPING.out.bam
    hic_pairs         = HIC_MAPPING.out.pairs
    depths            = COVERM_CONTIG.out.coverage
}
