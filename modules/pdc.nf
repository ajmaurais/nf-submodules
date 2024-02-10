
process GET_DOCKER_INFO {
    publishDir "${params.result_dir}/pdc", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'mauraisa/pdc_client:0.12'

    output:
        path('pdc_versions.txt'), emit: info_file

    shell:
        '''
        echo -e "GIT_HASH=${GIT_HASH}" > pdc_versions.txt
        echo -e "GIT_BRANCH=${GIT_BRANCH}" >> pdc_versions.txt
        echo -e "GIT_REPO=${GIT_REPO}" >> pdc_versions.txt
        echo -e "GIT_SHORT_HASH=${GIT_SHORT_HASH}" >> pdc_versions.txt
        echo -e "GIT_UNCOMMITTED_CHANGES=${GIT_UNCOMMITTED_CHANGES}" >> pdc_versions.txt
        echo -e "GIT_LAST_COMMIT=${GIT_LAST_COMMIT}" >> pdc_versions.txt
        echo -e "DOCKER_IMAGE=${DOCKER_IMAGE}" >> pdc_versions.txt
        echo -e "DOCKER_TAG=${DOCKER_TAG}" >> pdc_versions.txt
        '''
}

process GET_STUDY_ID {
    label 'process_low_constant'
    errorStrategy 'retry'
    maxRetries 2
    container 'mauraisa/pdc_client:0.12'

    input:
        val pdc_study_id

    output:
        stdout

    shell:
    '''
    PDC_client studyID !{params.pdc_client_args} !{pdc_study_id} |tee study_id.txt
    '''
}

process GET_STUDY_METADATA {
    publishDir "${params.result_dir}/pdc/study_metadata", failOnError: true, mode: 'copy'
    errorStrategy 'retry'
    maxRetries 2
    label 'process_low_constant'
    container 'mauraisa/pdc_client:0.12'

    input:
        val pdc_study_id

    output:
        path('study_metadata.tsv'), emit: metadata
        path('study_metadata_annotations.csv'), emit: skyline_annotations

    shell:
    n_files_arg = params.n_raw_files == null ? "" : "--nFiles ${params.n_raw_files}"
    '''
    PDC_client metadata !{params.pdc_client_args} -f tsv !{n_files_arg} --skylineAnnotations !{pdc_study_id}
    '''
}

process GET_FILE {
    label 'process_low_constant'
    container 'mauraisa/pdc_client:0.12'
    errorStrategy 'retry'
    maxRetries 2
    storeDir "${params.panorama_cache_directory}"

    input:
        tuple val(url), val(file_name), val(md5)

    output:
        path(file_name), emit: downloaded_file

    shell:
    '''
    PDC_client file -o '!{file_name}' -m '!{md5}' '!{url}'
    '''

    stub:
    """
    touch '${file_name}'
    """
}

