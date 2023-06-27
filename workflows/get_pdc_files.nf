
include { get_study_id } from "../modules/pdc.nf"
include { get_study_metadata } from "../modules/pdc.nf"
include { get_file } from "../modules/pdc.nf"
include { MSCONVERT } from "../modules/msconvert.nf"

workflow get_pdc_files {

    main:
        get_study_id(params.pdc_study_id) |get_study_metadata
        
        get_study_metadata.out.metadata \
            | splitCsv(header:true, sep:'\t') \
            | map{row -> tuple(row.url, row.file_name, row.md5sum)} \
            | get_file
        
        MSCONVERT(get_file.out.downloaded_file,
                  params.msconvert.do_demultiplex,
                  params.msconvert.do_simasspectra)

    emit:
        annotations_csv = get_study_metadata.out.skyline_annotations
        wide_mzml_ch = MSCONVERT.out.mzml_file
}

