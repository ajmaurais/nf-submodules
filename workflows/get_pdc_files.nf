
include { GET_STUDY_ID } from "../modules/pdc.nf"
include { GET_STUDY_METADATA } from "../modules/pdc.nf"
include { GET_FILE } from "../modules/pdc.nf"
include { MSCONVERT } from "../modules/msconvert.nf"

workflow get_pdc_study_metadata {
    emit:
        metadata
        annotations_csv

    main:
        if(params.pdc_metadata_tsv == null) {
            GET_STUDY_ID(params.pdc_study_id) |GET_STUDY_METADATA
            metadata = GET_STUDY_METADATA.out.metadata
            annotations_csv = GET_STUDY_METADATA.out.skyline_annotations
        } else {
            metadata = Channel.fromPath(file(params.pdc_metadata_tsv, checkIfExists: true))
            annotations_csv = Channel.fromPath(file(params.pdc_annotations_csv, checkIfExists: true))
        }
}

workflow get_pdc_files {
    emit:
        metadata
        annotations_csv
        wide_mzml_ch

    main:
        get_pdc_study_metadata()
        metadata = get_pdc_study_metadata.out.metadata
        annotations_csv = get_pdc_study_metadata.out.metadata

        metadata \
            | splitCsv(header:true, sep:'\t') \
            | map{row -> tuple(row.url, row.file_name, row.md5sum)} \
            | GET_FILE

        MSCONVERT(GET_FILE.out.downloaded_file,
                  params.msconvert.do_demultiplex,
                  params.msconvert.do_simasspectra)

        wide_mzml_ch = MSCONVERT.out.mzml_file
}

