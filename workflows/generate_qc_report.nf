
include { SKYLINE_EXPORT_REPORT as EXPORT_REPLICATE_REPORT } from "../modules/skyline.nf"
include { SKYLINE_EXPORT_REPORT as EXPORT_PRECURSOR_REPORT } from "../modules/skyline.nf"
include { MERGE_REPORTS as GENERATE_QC_REPORT_DB } from "../modules/qc_report.nf"
include { NORMALIZE_DB } from "../modules/qc_report.nf"
include { GENERATE_QC_QMD } from "../modules/qc_report.nf"
include { RENDER_QC_REPORT } from "../modules/qc_report.nf"

workflow generate_dia_qc_report {

    take:
        sky_file
        sky_artifacts
        study_name
        qc_report_title
        metadata_csv

    emit:
        qc_reports
        qc_report_qmd
        qc_report_db

    main:
        EXPORT_REPLICATE_REPORT(sky_file, sky_artifacts,
                                params.qc_report.replicate_report_template)
        EXPORT_PRECURSOR_REPORT(sky_file, sky_artifacts,
                                params.qc_report.precursor_report_template)

        GENERATE_QC_REPORT_DB(study_name,
                              EXPORT_REPLICATE_REPORT.out.report.collect(),
                              EXPORT_PRECURSOR_REPORT.out.report.collect(),
                              metadata_csv)

        NORMALIZE_DB(GENERATE_QC_REPORT_DB.out.final_db)

        GENERATE_QC_QMD(NORMALIZE_DB.out.normalized_db,
                        qc_report_title)

        report_formats = Channel.from(['html', 'pdf'])
        RENDER_QC_REPORT(GENERATE_QC_QMD.out.qc_report_qmd,
                         NORMALIZE_DB.out.normalized_db,
                         report_formats)

        qc_report_qmd = GENERATE_QC_QMD.out.qc_report_qmd
        qc_report_db = NORMALIZE_DB.out.normalized_db
        qc_reports = RENDER_QC_REPORT.out.qc_report
}

