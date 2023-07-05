
include { GET_STUDY_ID } from "../modules/pdc.nf"
include { GET_STUDY_METADATA } from "../modules/pdc.nf"
include { GET_FILE } from "../modules/pdc.nf"
include { MSCONVERT } from "../modules/msconvert.nf"

workflow get_pdc_study_metadata {

    main:
        GET_STUDY_ID(params.pdc_study_id) |GET_STUDY_METADATA

    emit:
        metadata = GET_STUDY_METADATA.out.metadata
        annotations_csv = GET_STUDY_METADATA.out.skyline_annotations
}

workflow get_pdc_files {

    main:
        get_pdc_study_metadata()

        get_pdc_study_metadata.out.metadata \
            | splitCsv(header:true, sep:'\t') \
            | map{row -> tuple(row.url, row.file_name, row.md5sum)} \
            | GET_FILE

        MSCONVERT(GET_FILE.out.downloaded_file,
                  params.msconvert.do_demultiplex,
                  params.msconvert.do_simasspectra)

    emit:
        metadata = get_pdc_study_metadata.out.metadata
        annotations_csv = get_pdc_study_metadata.out.annotations_csv
        wide_mzml_ch = MSCONVERT.out.mzml_file
}

