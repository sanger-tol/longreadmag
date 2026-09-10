include { GUNZIP                   } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM             } from '../../../modules/nf-core/metamdbg/asm'
include { MYLOASM                  } from '../../../modules/nf-core/myloasm'
include { SEMIBIN_CONCATENATEFASTA } from '../../../modules/nf-core/semibin/concatenatefasta/main'

workflow ASSEMBLY {
    take:
    ch_long_reads_assemblies
    val_assembler
    val_binners

    main:

    ch_assemblies = ch_long_reads_assemblies
        .filter { _meta, _reads, assembly -> assembly }
        .map { meta, _reads, assembly ->
            log.info("Skipping assembly for ${meta.id}: assembly provided")
            [meta, assembly]
        }

    ch_assembly_input = ch_long_reads_assemblies
        .filter { _meta, _reads, assembly -> !assembly }
        .map { meta, reads, _assembly -> [meta, reads] }

    if (val_assembler == "metamdbg") {
        //
        // Module: Assemble PacBio reads using metaMDBG
        //
        ch_metamdbg_input = ch_assembly_input.multiMap { meta, reads ->
            reads: [meta, reads]
            input_type: meta.platform == "pacbio_hifi" ? "hifi" : "ont"
        }

        METAMDBG_ASM(
            ch_metamdbg_input.reads,
            ch_metamdbg_input.input_type,
        )

        ch_assemblies = ch_assemblies.mix(
            METAMDBG_ASM.out.contigs.map { meta, contigs ->
                def meta_new = meta + [assembler: val_assembler]
                [meta_new, contigs]
            }
        )
    }
    else if (val_assembler == "myloasm") {
        //
        // Module: Assemble PacBio reads using myloasm
        //
        MYLOASM(ch_assembly_input)

        ch_assemblies = ch_assemblies.mix(
            MYLOASM.out.contigs.map { meta, contigs ->
                def meta_new = meta + [assembler: val_assembler]
                [meta_new, contigs]
            }
        )
    }

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies.branch { _meta, asm ->
        gzipped: asm.getExtension() == "gz"
        ungzipped: true
    }

    GUNZIP(ch_assemblies_split.gzipped)
    ch_assemblies_unzipped = ch_assemblies_split.ungzipped.mix(GUNZIP.out.gunzip)

    //
    // Module: Concatenate FASTAs for multisample split binning if requested
    //
    ch_assemblies_to_concatenate = ch_assemblies
        .filter { val_binners.semibin2 || val_binners.vamb }
        .toSortedList { a, b -> a[0].id <=> b[0].id }
        .map { list ->
            def ids = []
            def assemblers = []
            def out_assemblies = []
            list.collect { meta, fasta ->
                ids << meta.id
                assemblers << meta.assembler
                out_assemblies << fasta
            }

            return [[id: "collated", collated: true, ids: ids, assemblers: assemblers], out_assemblies]
        }

    SEMIBIN_CONCATENATEFASTA(ch_assemblies_to_concatenate)

    emit:
    assemblies              = ch_assemblies_unzipped
    concatenated_assemblies = SEMIBIN_CONCATENATEFASTA.out.concat_fasta
}
