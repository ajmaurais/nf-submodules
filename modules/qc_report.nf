
process GENERATE_DIA_QC_REPORT_DB {
    publishDir "${params.result_dir}/skyline/qc_report", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    container 'mauraisa/dia_qc_report:0.1'
    
    input:
        path replicate_report
        path precursor_report
        val standard_proteins
        val qc_report_title

    output:
        path('qc_report_data.db3'), emit: qc_report_db
        path('qc_report.qmd'), emit: qc_report_qmd

    script:
        standard_proteins_args = "--addStdProtein ${(standard_proteins as List).collect{it}.join(' --addStdProtein ')}"
        """
        parse_data --ofname qc_report_data.db3 '${replicate_report}' '${precursor_report}'

        make_qmd --title '${qc_report_title}' qc_report_data.db3
        """
}

process RENDER_QC_REPORT {
    publishDir "${params.result_dir}/skyline/qc_report", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    container 'mauraisa/dia_qc_report:0.1'
    
    input:
        path qmd
        path database
        val report_format

    output:
        path("qc_report.${format}"), emit: qc_report

    script:
        format = report_format
        """
        quarto render qc_report.qmd --to '${format}'
        """
}
