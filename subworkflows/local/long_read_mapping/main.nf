include { FILTER_BAM           } from '../../../modules/local/filter_bam'

include { FASTX_MAP_LONG_READS } from '../../../subworkflows/sanger-tol/fastx_map_long_reads'

workflow LONG_READ_MAPPING {
    take:
    ch_assemblies
    ch_long_reads
    ch_filter_list
    val_mapping_options

    main:
    //
    // Subworkflow: Chunked mapping of long reads to metagenome assembly
    //
    ch_pacbio_mapping_inputs = ch_assemblies
        .combine(ch_long_reads)
        .multiMap { meta, asm, _meta_pb, reads ->
            def meta_new = meta + [read_name: reads.getName()]
            assemblies: [meta_new, asm]
            reads: [meta_new, reads]
        }

    FASTX_MAP_LONG_READS(
        ch_pacbio_mapping_inputs.assemblies,
        ch_pacbio_mapping_inputs.reads,
        val_mapping_options.long_read_mapping_reads_per_chunk,
        true,
        channel.empty(),
    )

    //
    // Logic: if we have removed circular contigs from binning, strip them
    // out of the coverage TSV
    //
    ch_filter_bam_input = FASTX_MAP_LONG_READS.out.bam
        .join(ch_filter_list, by: 0, remainder: true)
        .branch { meta, bam, filter_list ->
            filter: filter_list || filter_list.size() > 0
            skip_filter: true
            return [meta, bam]
        }

    //
    // Module: filter unwanted references from bam
    //
    FILTER_BAM(ch_filter_bam_input.filter)

    ch_output_bam = FASTX_MAP_LONG_READS.out.bam.map { meta, bam -> [meta - meta.subMap("read_name"), bam] }.groupTuple(by: 0)
    ch_output_filtered_bam = FILTER_BAM.out.bam
        .mix(FILTER_BAM.out.bam)
        .map { meta, bam -> [meta - meta.subMap("read_name"), bam] }
        .groupTuple(by: 0)

    emit:
    bam          = ch_output_bam
    filtered_bam = ch_output_filtered_bam
}
