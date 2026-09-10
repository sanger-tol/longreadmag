include { TIARA_TIARA      } from '../../../modules/nf-core/tiara/tiara'
include { SEQKIT_STATS     } from '../../../modules/nf-core/seqkit/stats'
include { GENOMAD_ENDTOEND } from '../../../modules/nf-core/genomad/endtoend'

workflow ASSEMBLY_ANALYSIS {
    take:
    ch_assemblies
    ch_concatenated_assemblies
    ch_genomad_db
    val_enable_tiara
    val_enable_genomad

    main:
    //
    // Module: Calculate basic assembly statistics
    //
    SEQKIT_STATS(ch_assemblies)

    //
    // Module: Classify assembled contigs with tiara to domain level
    //
    TIARA_TIARA(ch_assemblies.mix(ch_concatenated_assemblies).filter { val_enable_tiara })

    //
    // Module: Run Genomad on the assembly
    //
    GENOMAD_ENDTOEND(
        ch_assemblies.filter { val_enable_genomad },
        ch_genomad_db,
    )

    emit:
    assembly_statistics   = SEQKIT_STATS.out.stats
    tiara_classifications = TIARA_TIARA.out.classifications
    genomad_results       = GENOMAD_ENDTOEND.out.genomad_results
}
