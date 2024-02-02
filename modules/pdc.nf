
process GET_STUDY_ID {
    label 'process_low_constant'
    errorStrategy 'retry'
    maxRetries 2
    container 'mauraisa/pdc_client:0.8'

    input:
        val pdc_study_id

    output:
        stdout

    shell:
    '''
    PDC_client studyID --baseUrl !{params.pdc_base_url} !{pdc_study_id} |tee study_id.txt
    '''
}

process GET_STUDY_METADATA {
    publishDir "${params.result_dir}/pdc/study_metadata", pattern: "study_metadata_*", failOnError: true, mode: 'copy'
    errorStrategy 'retry'
    maxRetries 2
    label 'process_low_constant'
    container 'mauraisa/pdc_client:0.8'
    
    input:
        val pdc_study_id

    output:
        path('study_metadata.tsv'), emit: metadata
        path('study_metadata_annotations.csv'), emit: skyline_annotations

    shell:
    n_files_arg = params.n_raw_files == null ? "" : "--nFiles ${params.n_raw_files}"
    '''
    PDC_client metadata --baseUrl !{params.pdc_base_url} -f tsv !{n_files_arg} --skylineAnnotations !{pdc_study_id}
    '''
}

process GET_FILE {
    label 'process_low_constant'
    container 'mauraisa/pdc_client:0.8'
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

