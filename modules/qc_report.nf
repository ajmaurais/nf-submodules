
def format_flag(var, flag) {
    ret = (var == null ? "" : "${flag} ${var}")
    return ret
}

def format_flags(vars, flag) {
    if(vars instanceof List) {
        return (vars == null ? "" : "${flag} \'${vars.join('\' ' + flag + ' \'')}\'")
    }
    return format_flag(vars, flag)
}

process GET_DOCKER_INFO {
    publishDir "${params.result_dir}/qc_report", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'mauraisa/dia_qc_report:1.6'

    output:
        path('dia_qc_report_versions.txt'), emit: info_file

    shell:
        '''
        echo -e "GIT_HASH=${GIT_HASH}" > dia_qc_report_versions.txt
        echo -e "GIT_BRANCH=${GIT_BRANCH}" >> dia_qc_report_versions.txt
        echo -e "GIT_REPO=${GIT_REPO}" >> dia_qc_report_versions.txt
        echo -e "GIT_SHORT_HASH=${GIT_SHORT_HASH}" >> dia_qc_report_versions.txt
        echo -e "GIT_UNCOMMITTED_CHANGES=${GIT_UNCOMMITTED_CHANGES}" >> dia_qc_report_versions.txt
        echo -e "GIT_LAST_COMMIT=${GIT_LAST_COMMIT}" >> dia_qc_report_versions.txt
        echo -e "DOCKER_IMAGE=${DOCKER_IMAGE}" >> dia_qc_report_versions.txt
        echo -e "DOCKER_TAG=${DOCKER_TAG}" >> dia_qc_report_versions.txt
        '''
}

process GENERATE_QC_QMD {
    publishDir "${params.result_dir}/qc_report", failOnError: true, mode: 'copy'
    label 'process_medium'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        path qc_report_db
        val qc_report_title

    output:
        path('qc_report.qmd'), emit: qc_report_qmd
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        standard_proteins_args = "--addStdProtein ${(params.qc_report.standard_proteins as List).collect{it}.join(' --addStdProtein ')}"
        color_vars_args = "--addColorVar ${(params.qc_report.color_vars as List).collect{it}.join(' --addColorVar ')}"
        """
        generate_qc_qmd ${standard_proteins_args} ${color_vars_args} --title '${qc_report_title}' ${qc_report_db} \
            > >(tee "make_qmd.stdout") 2> >(tee "make_qmd.stderr" >&2)
        """

    stub:
        """
        touch qc_report.qmd
        touch stub.stdout stub.stderr
        """
}

process RENDER_QC_REPORT {
    publishDir "${params.result_dir}/qc_report", pattern: 'qc_report.*', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/qc_report", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        path qmd
        path database
        val report_format

    output:
        path("qc_report.${report_format}"), emit: qc_report
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        """
        quarto render qc_report.qmd --to '${report_format}' \
            > >(tee "render_${report_format}_report.stdout") 2> >(tee "render_${report_format}_report.stderr" >&2)
        """

    stub:
        """
        touch "qc_report.${report_format}"
        touch stub.stdout stub.stderr
        """
}


process NORMALIZE_DB {
    publishDir "${params.result_dir}/batch_report/normalize_db", failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        path batch_db

    output:
        path("normalized_${batch_db.baseName}.db3"), emit: normalized_db
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        """
        # Copying the database is necissary because the nextflow -resume flag
        # will not work unless we create a new file
        cp -v ${batch_db} "normalized_${batch_db.baseName}.db3"

        normalize_db "normalized_${batch_db.baseName}.db3" \
            > >(tee "normalize_db.stdout") 2> >(tee "normalize_db.stderr" >&2)
        """

    stub:
        """
        touch "normalized_${batch_db.baseName}.db3"
        touch stub.stdout stub.stderr
        """
}

process GENERATE_BATCH_RMD {
    publishDir "${params.result_dir}/batch_report/rmd", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        path normalized_db

    output:
        path("bc_report.rmd"), emit: bc_rmd
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        """
        generate_batch_rmd \
            ${format_flag(params.bc.method, "--bcMethod")} \
            ${format_flag(params.bc.batch1, "--batch1")} \
            ${format_flag(params.bc.batch2, "--batch2")} \
            ${format_flags(params.bc.color_vars, "--addColor")} \
            ${format_flag(params.bc.control_key, "--controlKey")} \
            ${format_flags(params.bc.control_values, "--addControlValue")} \
            ${format_flags(params.bc.covariate_vars, "--addCovariate")} \
            ${format_flag(params.bc.plot_ext, "--savePlots")} \
            --precursorTables 70 --proteinTables 70 \
            ${normalized_db} \
        > >(tee "generate_batch_rmd.stdout") 2> >(tee "generate_batch_rmd.stderr" >&2)
        """

    stub:
        """
        touch bc_report.rmd
        touch stub.stdout stub.stderr
        """
}


process RENDER_BATCH_RMD {
    publishDir "${params.result_dir}/batch_report/rmd", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd/tables", pattern: '*.tsv', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stdout', failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/batch_report/rmd", pattern: '*.stderr', failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        path batch_rmd
        path normzlize_db

    output:
        path("bc_report.html"), emit: bc_html
        path("*.tsv"), emit: tsv_reports, optional: true
        path("plots/*"), emit: bc_plots, optional: true
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        """
        mkdir plots
        Rscript -e "rmarkdown::render('${batch_rmd}')" \
            > >(tee -a "render_batch_rmd.stdout") 2> >(tee -a "render_batch_rmd.stderr" >&2)
        """

    stub:
        """
        touch bc_report.html
        touch stub.stdout stub.stderr
        """
}


process MERGE_REPORTS {
    publishDir "${params.result_dir}/batch_report/merge_reports", failOnError: true, mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/dia_qc_report:1.6'

    input:
        val study_names
        path replicate_reports
        path precursor_reports
        path metadatas

    output:
        path('data.db3'), emit: final_db
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

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
                > >(tee -a "parse_data.stdout") 2> >(tee -a "parse_data.stderr" >&2)

            echo "Done!"
        done
        '''

    stub:
        """
        touch data.db3
        touch stub.stdout stub.stderr
        """
}

