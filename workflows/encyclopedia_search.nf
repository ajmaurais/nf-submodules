// Modules
include { ENCYCLOPEDIA_SEARCH_FILE } from "../modules/encyclopedia"
include { ENCYCLOPEDIA_CREATE_ELIB } from "../modules/encyclopedia"

workflow encyclopedia_search {

    take:
        mzml_file_ch
        fasta
        dlib
        align_between_runs
        output_file_prefix
        encyclopedia_params

    emit:
        elib

    main:

        // run encyclopedia for each mzML file
        ENCYCLOPEDIA_SEARCH_FILE(
            mzml_file_ch,
            fasta,
            dlib,
            encyclopedia_params
        )

        // aggregate results into single elib
        ENCYCLOPEDIA_CREATE_ELIB(
            ENCYCLOPEDIA_SEARCH_FILE.out.elib.collect(),
            ENCYCLOPEDIA_SEARCH_FILE.out.dia.collect(),
            ENCYCLOPEDIA_SEARCH_FILE.out.features.collect(),
            ENCYCLOPEDIA_SEARCH_FILE.out.results_targets.collect(),
            ENCYCLOPEDIA_SEARCH_FILE.out.results_decoys.collect(),
            fasta,
            dlib,
            align_between_runs,
            output_file_prefix,
            encyclopedia_params
        )

        elib = ENCYCLOPEDIA_CREATE_ELIB.out.elib
}
