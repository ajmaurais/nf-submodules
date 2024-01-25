
process GENERATE_DIA_QC_REPORT_DB {
    publishDir "${params.result_dir}/qc_report", pattern: '*.db3', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.qmd', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.1'

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
        parse_data --ofname qc_report_data.db3 '${replicate_report}' '${precursor_report}' \
            > >(tee "parse_data.stdout") 2> >(tee "parse_data.stderr")

        generate_qc_qmd ${standard_proteins_args} --title '${qc_report_title}' qc_report_data.db3 \
            > >(tee "make_qmd.stdout") 2> >(tee "make_qmd.stderr")
        """
}

process RENDER_QC_REPORT {
    publishDir "${params.result_dir}/qc_report", pattern: 'qc_report.*', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.1'

    input:
        path qmd
        path database
        val report_format

    output:
        path("qc_report.${format}"), emit: qc_report

    script:
        format = report_format
        """
        quarto render qc_report.qmd --to '${format}' \
            > >(tee "render_${report_format}_report.stdout") 2> >(tee "render_${report_format}_report.stderr")
        """

    stub:
        """
        touch "qc_report.${format}"
        """
}


process NORMALIZE_DB {
    publishDir "${params.result_dir}/batch_report/normzlize_db", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/normalzie_db", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/normalize_db", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.1'

    input:
        path batch_db

    output:
        path("normalized_${batch_db.baseName}.db3"), emit: normalized_db

    script:
        """
        # Copying the database is necissary because the nextflow -resume flag
        # will not work unless we create a new file
        cp -v ${batch_db} "normalized_${batch_db.baseName}.db3"

        normalize_db "normalized_${batch_db.baseName}.db3" \
            > >(tee -a "normalize_db.stdout") 2> >(tee -a "normalize_db.stderr")
        """

    stub:
        """
        touch "normalized_${batch_db.baseName}.db3"
        """
}


process GENERATE_BATCH_RMD {
    publishDir "${params.result_dir}/batch_report/rmd", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_low'
    container 'mauraisa/dia_qc_report:1.1'

    input:
        path normalized_db

    output:
        path("bc_report.rmd"), emit: bc_rmd

    script:
        """
        generate_batch_rmd ${normalized_db} \
            > >(tee -a "generate_batch_rmd.stdout") 2> >(tee -a "genrate_batch_rmd.stderr")
        """

    stub:
        """
        touch bc_report.rmd
        """
}


process RENDER_BATCH_RMD {
    publishDir "${params.result_dir}/batch_report/rmd", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.1'

    input:
        path batch_rmd
        path normzlize_db

    output:
        path("bc_report.html"), emit: bc_html
        path("*.tsv"), emit: tsv_reports, optional: true

    script:
        """
        Rscript -e "rmarkdown::render('${batch_rmd}')"
            > >(tee -a "render_batch_rmd.stdout") 2> >(tee -a "render_batch_rmd.stderr")
        """

    stub:
        """
        touch bc_report.html
        """
}


process MERGE_REPORTS {
    publishDir "${params.result_dir}/batch_report", failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.1'

    input:
        val study_names
        path replicate_reports
        path precursor_reports
        path metadatas

    output:
        path('data.db3'), emit: final_db

    shell:
        '''
        study_names_array=( '!{study_names.join("' '")}' )
        replicate_reports_array=( '!{replicate_reports.join("' '")}' )
        precursor_reports_array=( '!{precursor_reports.join("' '")}' )
        metadata_array=( '!{metadatas.join("' '")}' )

        for i in ${!study_names_array[@]} ; do
            echo "Working on ${study_names_array[$i]}..."

            parse_data --overwriteMode=append \
                --projectName="${study_names_array[$i]}" \
                --metadata="${metadata_array[$i]}" \
                "${replicate_reports_array[$i]}" \
                "${precursor_reports_array[$i]}" \
                > >(tee -a "parse_data.stdout") 2> >(tee -a "parse_data.stderr")

            echo "Done!"
        done
        '''

    stub:
        """
        touch data.db3
        """
}

