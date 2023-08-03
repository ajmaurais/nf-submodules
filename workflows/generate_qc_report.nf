
include { SKYLINE_EXPORT_REPORT as export_replicate_report } from "../modules/skyline.nf"
include { SKYLINE_EXPORT_REPORT as export_precursor_report } from "../modules/skyline.nf"
include { GENERATE_DIA_QC_REPORT_DB } from "../modules/qc_report.nf"
include { RENDER_QC_REPORT } from "../modules/qc_report.nf"

workflow generate_dia_qc_report {

    take:
        final_skyline_zip 
        qc_report_title

    emit:
        qc_reports
        qc_report_qmd
        qc_report_db
    
    main:
        export_replicate_report(final_skyline_zip, params.qc_report.replicate_report_template) 
        export_precursor_report(final_skyline_zip, params.qc_report.precursor_report_template) 
        
        GENERATE_DIA_QC_REPORT_DB(export_replicate_report.out.report,
                                  export_precursor_report.out.report,
                                  params.qc_report.standard_proteins,
                                  qc_report_title)

        qc_report_qmd = GENERATE_DIA_QC_REPORT_DB.out.qc_report_qmd
        qc_report_db = GENERATE_DIA_QC_REPORT_DB.out.qc_report_db

        report_formats = Channel.from(['html', 'pdf'])
        RENDER_QC_REPORT(GENERATE_DIA_QC_REPORT_DB.out.qc_report_qmd,
                         GENERATE_DIA_QC_REPORT_DB.out.qc_report_db,
                         report_formats)
        qc_reports = RENDER_QC_REPORT.out.qc_report
}

