
process SKYLINE_ADD_LIB {
    publishDir "${params.result_dir}/skyline/add-lib", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_medium'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.22335-b595b19'

    input:
        path skyline_template_zipfile
        path fasta
        path elib

    output:
        path("results.sky.zip"), emit: skyline_zipfile
        path("skyline_add_library.log"), emit: log

    script:
    """
    unzip ${skyline_template_zipfile}

    wine SkylineCmd \
        --in="${skyline_template_zipfile.baseName}" \
        --log-file=skyline_add_library.log \
        --import-fasta="${fasta}" \
        --add-library-path="${elib}" \
        --out="results.sky" \
        --save \
        --share-zip="results.sky.zip" \
        --share-type="complete"
    """
}

process SKYLINE_IMPORT_MZML {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_medium'
    label 'process_high_memory'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.22335-b595b19'

    input:
        path skyline_zipfile
        path mzml_file

    output:
        path("*.skyd"), emit: skyd_file
        path("${mzml_file.baseName}.log"), emit: log_file

    script:
    """
    unzip ${skyline_zipfile}

    cp ${mzml_file} /tmp/${mzml_file}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --log-file="${mzml_file.baseName}.log" \
        --import-file="/tmp/${mzml_file}" \
    """
}

process SKYLINE_MERGE_RESULTS {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_high'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.22335-b595b19'

    input:
        path skyline_zipfile
        path skyd_files
        val mzml_files

    output:
        path("final.sky.zip"), emit: final_skyline_zipfile
        path("skyline-merge.log"), emit: log

    script:
    import_files_params = "--import-file=${(mzml_files as List).collect{ "/tmp/" + file(it).name }.join(' --import-file=')}"
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --log-file="skyline-merge.log" \
        ${import_files_params} \
        --out="final.sky" \
        --save \
        --share-zip="final.sky.zip" \
        --share-type="complete"
    """
}

process SKYLINE_ANNOTATE_DOCUMENT {
    publishDir "${params.result_dir}/skyline/annotated", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.22335-b595b19'

    input:
        path skyline_zipfile
        path annotation_csv

    output:
        path("final.sky.zip"), emit: final_skyline_zipfile
        path("skyline-annotate.log"), emit: log

    script:
    """
    unzip "${skyline_zipfile}"

    wine SkylineCmd --in="${skyline_zipfile.baseName}" \
        --log-file=skyline-annotate.log \
        --out="final_annotated.sky" \
        --import-annotations="${annotation_csv}" --save \
        --share-zip="final_annotated.sky.zip"
    """
}

process SKYLINE_EXPORT_REPORT {
    publishDir "${params.result_dir}/skyline/reports", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.22335-b595b19'

    input:
        path skyline_zipfile
        path report_template

    output:
        path("${report_name}.tsv"), emit: report
        path("skyline-export-report.log"), emit: log

    script:
    report_name = report_template.baseName
    """
    # unzip skyline input file
    unzip "${skyline_zipfile}"
    # unzip "${skyline_zipfile}"| grep 'inflating'| sed -E 's/\s?inflating:\s?//' > archive_files.txt

    wine SkylineCmd --in="${skyline_zipfile.baseName}" \
        --log-file=skyline-export-report.log \
        --report-add="${report_template}" \
        --report-conflict-resolution="overwrite" --report-format="tsv" --report-invariant \
        --report-name="${report_name}" --report-file="${report_name}.tsv"
    """
}

