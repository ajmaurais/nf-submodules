
process SKYLINE_ADD_LIB {
    publishDir "${params.result_dir}/skyline/add-lib", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_medium'
    label 'error_retry'
    stageInMode 'link'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24020-c3a52ef'

    input:
        path skyline_template_zipfile
        path fasta
        path elib

    output:
        path("results.sky.zip"), emit: skyline_zipfile
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    unzip ${skyline_template_zipfile}

    wine SkylineCmd \
        --in="${skyline_template_zipfile.baseName}" \
        --import-fasta="${fasta}" \
        --add-library-path="${elib}" \
        --out="results.sky" \
        --save \
        --share-zip="results.sky.zip" \
        --share-type="complete"
    > >(tee 'skyline_add_library.stdout') 2> >(tee 'skyline_add_library.stderr' >&2)
    """

    stub:
    """
    touch results.sky.zip
    touch stub.stderr stub.stdout
    """
}

process SKYLINE_IMPORT_MZML {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_medium'
    label 'process_high_memory'
    label 'error_retry'
    stageInMode 'link'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24020-c3a52ef'

    input:
        path skyline_zipfile
        path mzml_file

    output:
        path("*.skyd"), emit: skyd_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --import-file="/tmp/${mzml_file}" \
    > >(tee 'import_${mzml_file.baseName}.stdout') 2> >(tee 'import_${mzml_file.baseName}.stderr' >&2)
    """

    stub:
    """
    touch "${mzml_file.baseName}.skyd"
    touch stub.stderr stub.stdout
    """
}

process SKYLINE_MERGE_RESULTS {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_high'
    label 'error_retry'
    stageInMode 'link'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24020-c3a52ef'

    input:
        path skyline_zipfile
        path skyd_files
        path mzml_files

    output:
        path("final.sky.zip"), emit: final_skyline_zipfile
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    import_files_params = "--import-file=${(mzml_files as List).collect{ file(it).name }.join(' --import-file=')}"
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        ${import_files_params} \
        --out="final.sky" \
        --save \
        --share-zip="final.sky.zip" \
        --share-type="complete" \
    > >(tee 'merge_skyline.stdout') 2> >(tee 'merge_skyline.stderr' >&2)
    """

    stub:
    """
    touch final.sky.zip
    touch stub.stdout stub.stderr
    """
}

process UNZIP_SKY_FILE {
    publishDir "${params.result_dir}/skyline/unzip", failOnError: true, pattern: '*.archive_files.txt', mode: 'copy'
    label 'process_high_memory'
    container 'mauraisa/aws_bash:0.5'

    input:
        path(sky_zip_file)

    output:
        path("*.sky"), emit: sky_file
        path("*.skyd"), emit: skyd_file
        path("*.[eb]lib"), emit: lib_file
        path("*.archive_files.txt"), emit: log

    script:
    """
    unzip ${sky_zip_file} |tee ${sky_zip_file.baseName}.archive_files.txt
    """

    stub:
    """
    touch ${sky_zip_file.baseName}
    touch ${sky_zip_file.baseName}d
    touch lib.blib
    touch ${sky_zip_file.baseName}.archive_files.txt
    """
}

process SKYLINE_ANNOTATE_DOCUMENT {
    publishDir "${params.result_dir}/skyline/annotate", pattern: "*.stdout", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/skyline/annotate", pattern: "*.stderr", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    stageInMode 'link'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24020-c3a52ef'

    input:
        path sky_file
        path skyd_file
        path lib_file
        path annotation_csv

    output:
        path("final_annotated.sky.zip"), emit: sky_zip_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    shell:
    '''
    wine SkylineCmd --in="!{sky_file}" \
        --out="final_annotated.sky" \
        --import-annotations="!{annotation_csv}" --save \
        --share-zip="final_annotated.sky.zip" \
    > >(tee 'annotate_doc.stdout') 2> >(tee 'annotate_doc.stderr' >&2)
    '''

    stub:
    '''
    touch "final_annotated.sky"
    touch "final_annotated.skyd"
    touch "stub.blib"
    touch stub.stdout stub.stderr
    '''
}

process SKYLINE_EXPORT_REPORT {
    publishDir "${params.result_dir}/skyline/reports", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    stageInMode 'link'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24020-c3a52ef'

    input:
        path sky_file
        path skyd_file
        path lib_file
        path report_template

    output:
        path("${report_template.baseName}.tsv"), emit: report
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    wine SkylineCmd --in="${sky_file}" \
        --report-add="${report_template}" \
        --report-conflict-resolution="overwrite" --report-format="tsv" --report-invariant \
        --report-name="${report_template.baseName}" --report-file="${report_template.baseName}.tsv" \
    > >(tee 'export_${report_template.baseName}.stdout') 2> >(tee 'export_${report_template.baseName}.stderr' >&2)
    """
    
    stub:
    """
    touch "${report_template.baseName}.tsv"
    touch stub.stdout stub.stderr
    """
}
