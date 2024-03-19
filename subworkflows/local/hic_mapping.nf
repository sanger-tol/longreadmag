#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//


workflow HIC_MAPPING {

    take:
    reference_ch        // Channel: tuple [ val(meta), file( reference_file ) ]
    dot_genome          // Channel: tuple [ val(meta), [ file( datafile ) ]   ]
    read_ch             // Channel: tuple [ val(meta), val( str )             ]  read channel (.fasta.gz)

    main:
    ch_versions                 = Channel.empty()
    


    emit:
    versions                = ch_versions
}