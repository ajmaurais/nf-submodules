
include { SKYLINE_EXPORT_REPORT as EXPORT_REPLICATE_REPORT } from "../modules/skyline.nf"
include { SKYLINE_EXPORT_REPORT as EXPORT_PRECURSOR_REPORT } from "../modules/skyline.nf"
include { MERGE_REPORTS as GENERATE_QC_REPORT_DB } from "../modules/qc_report.nf"
include { GENERATE_QC_QMD } from "../modules/qc_report.nf"
include { RENDER_QC_REPORT } from "../modules/qc_report.nf"
include { GET_DOCKER_INFO } from "../modules/qc_report.nf"

workflow generate_dia_qc_report {

    take:
        sky_file
        skyd_file
        sky_lib_file
        study_name
        qc_report_title
        metadata_csv

    emit:
        qc_reports
        qc_report_qmd
        qc_report_db
        docker_tag

    main:
        EXPORT_REPLICATE_REPORT(sky_file, skyd_file, sky_lib_file,
                                params.qc_report.replicate_report_template)
        EXPORT_PRECURSOR_REPORT(sky_file, skyd_file, sky_lib_file,
                                params.qc_report.precursor_report_template)

        GENERATE_QC_REPORT_DB(study_name,
                      EXPORT_REPLICATE_REPORT.out.report,
                      EXPORT_PRECURSOR_REPORT.out.report,
                      metadata_csv)

        GENERATE_QC_QMD(GENERATE_QC_REPORT_DB.out.final_db,
                        params.qc_report.standard_proteins,
                        qc_report_title)

        report_formats = Channel.from(['html', 'pdf'])
        RENDER_QC_REPORT(GENERATE_QC_QMD.out.qc_report_qmd,
                         GENERATE_QC_REPORT_DB.out.final_db,
                         report_formats)

        GET_DOCKER_INFO()

        qc_report_qmd = GENERATE_QC_QMD.out.qc_report_qmd
        qc_report_db = GENERATE_QC_REPORT_DB.out.final_db
        qc_reports = RENDER_QC_REPORT.out.qc_report
        docker_tag = GET_DOCKER_INFO.out.docker_tag
}

