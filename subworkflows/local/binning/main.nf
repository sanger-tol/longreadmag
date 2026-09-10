include { COMEBIN_RUNCOMEBIN                 } from '../../../modules/nf-core/comebin/runcomebin'
include { MAXBIN2                            } from '../../../modules/nf-core/maxbin2'
include { GAWK as GAWK_FASTATOCONTIG2BIN     } from '../../../modules/nf-core/gawk'
include { GAWK as GAWK_MAXBIN2_DEPTHS        } from '../../../modules/nf-core/gawk'
include { METABAT2_METABAT2                  } from '../../../modules/nf-core/metabat2/metabat2'
include { METATOR_PIPELINE                   } from '../../../modules/nf-core/metator/pipeline'
include { SEMIBIN_MULTIEASYBIN               } from '../../../modules/nf-core/semibin/multieasybin/main'
include { SEMIBIN_SINGLEEASYBIN              } from '../../../modules/nf-core/semibin/singleeasybin'
include { SEQKIT_REPLACE as FIX_METATOR_BINS } from '../../../modules/nf-core/seqkit/replace'
include { SEQKIT_SPLIT2 as SPLIT_CIRCLES     } from '../../../modules/nf-core/seqkit/split2'

include { BINNING_VAMB                       } from '../../../subworkflows/local/binning_vamb'
include { BINNING_VAMB as BINNING_TAXVAMB    } from '../../../subworkflows/local/binning_vamb'

workflow BINNING {
    take:
    ch_assemblies
    ch_circular_contigs
    ch_depths
    ch_bams
    ch_hic_pairs
    ch_centrifuger_db
    val_binners

    main:
    ch_bins = channel.empty()

    ch_assemblies_individual = ch_assemblies.filter { meta, _fasta -> !meta?.collated }
    ch_assemblies_collated = ch_assemblies.filter { meta, _fasta -> meta?.collated }
    ch_bam_individual = ch_bams.filter { meta, _bam -> !meta?.collated }
    ch_bam_collated = ch_bams.filter { meta, _bam -> meta?.collated }


    //
    // Module: Split circular contigs into separate bin files
    //
    if (val_binners.circular) {
        SPLIT_CIRCLES(ch_circular_contigs.map { meta, contigs -> [meta + [single_end: true], contigs] })

        ch_bins = ch_bins.mix(
            SPLIT_CIRCLES.out.reads.map { meta, fasta ->
                [meta - meta.subMap("single_end") + [binner: "circular"], fasta]
            }
        )
    }

    //
    // Module: Bin assembly using Metabat2
    //
    if (val_binners.metabat2) {
        METABAT2_METABAT2(
            ch_assemblies_individual.combine(ch_depths, by: 0)
        )

        ch_bins = ch_bins.mix(
            METABAT2_METABAT2.out.fasta.map { meta, fasta -> [meta + [binner: "metabat2"], fasta] }
        )
    }

    //
    // Logic: Bin assembly with MaxBin2
    //
    if (val_binners.maxbin2) {
        GAWK_MAXBIN2_DEPTHS(ch_depths, file("${projectDir}/bin/convert_depths_maxbin2.awk"), true)

        ch_maxbin2_input = ch_assemblies_individual
            .combine(GAWK_MAXBIN2_DEPTHS.out.output, by: 0)
            .map { meta, contigs, depths ->
                [meta, contigs, [], depths]
            }

        //
        // Module: Bin assembly using MaxBin2
        //
        MAXBIN2(ch_maxbin2_input)

        ch_bins = ch_bins.mix(
            MAXBIN2.out.binned_fastas.map { meta, fasta -> [meta + [binner: "maxbin2"], fasta] }
        )
    }

    if (val_binners.comebin) {
        //
        // Module: Bin assembly using Comebin
        //
        ch_comebin_input = ch_assemblies_individual
            .combine(ch_bam_individual, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        COMEBIN_RUNCOMEBIN(ch_comebin_input)

        ch_bins = ch_bins.mix(
            COMEBIN_RUNCOMEBIN.out.bins.map { meta, fasta -> [meta + [binner: "comebin"], fasta] }
        )
    }

    if (val_binners.semibin2_single) {
        //
        // Module: Bin assembly using Semibin
        //
        ch_semibin_input = ch_assemblies_individual
            .combine(ch_bam_individual, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        SEMIBIN_SINGLEEASYBIN(ch_semibin_input)

        ch_bins = ch_bins.mix(
            SEMIBIN_SINGLEEASYBIN.out.output_fasta.map { meta, fasta -> [meta + [binner: "semibin_single"], fasta] }
        )
    }

    if (val_binners.semibin2_multi) {
        ch_semibin_input = ch_assemblies_collated
            .combine(ch_bam_collated, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        SEMIBIN_MULTIEASYBIN(ch_semibin_input)

        ch_semibin_multi_bins = SEMIBIN_MULTIEASYBIN.out.output_fasta.flatMap { meta, bins ->
            return meta.ids
                .withIndex()
                .collect { id, idx ->
                    def bins_subset = bins.findAll { bin -> bin.getName() =~ id }
                    def assembler = meta.assemblers[idx]
                    return [[id: id, binner: "semibin_multi", assembler: assembler], bins_subset]
                }
        }
        ch_bins = ch_bins.mix(ch_semibin_multi_bins)
    }

    if (val_binners.vamb) {
        //
        // Subworkflow: Bin assembly with VAMB in standard mode
        //
        BINNING_VAMB(
            ch_assemblies,
            ch_depths,
            false,
            channel.empty(),
        )

        ch_bins = ch_bins.mix(BINNING_VAMB.out.single_bins)
        ch_bins = ch_bins.mix(BINNING_VAMB.out.multi_bins)
    }

    if (val_binners.taxvamb) {
        //
        // Subworkflow: Bin assembly with VAMB with taxonomy
        //
        BINNING_TAXVAMB(
            ch_assemblies,
            ch_depths,
            true,
            ch_centrifuger_db,
        )

        ch_bins = ch_bins.mix(BINNING_TAXVAMB.out.single_bins)
        ch_bins = ch_bins.mix(BINNING_TAXVAMB.out.multi_bins)
    }

    if (val_binners.metator) {
        //
        // Module: Bin assembly using Metator
        //
        ch_metator_inputs = ch_assemblies_individual
            .combine(ch_hic_pairs, by: 0)
            .map { meta, asm, pairs ->
                [meta, asm, pairs, []]
            }

        METATOR_PIPELINE(ch_metator_inputs)

        //
        // Module: Metator keeps the contig descriptions whereas all other binners drop them
        // This causes problems downstream.
        //
        FIX_METATOR_BINS(METATOR_PIPELINE.out.bins.transpose(), "fa.gz")

        ch_bins = ch_bins.mix(
            FIX_METATOR_BINS.out.fastx.groupTuple(by: 0).map { meta, fasta -> [meta + [binner: "metator"], fasta] }
        )
    }

    //
    // Module: Create contig2bin maps for all output bins
    //
    GAWK_FASTATOCONTIG2BIN(ch_bins, file("${projectDir}/bin/fastatocontig2bin.awk"), false)

    emit:
    bins       = ch_bins
    contig2bin = GAWK_FASTATOCONTIG2BIN.out.output
}
