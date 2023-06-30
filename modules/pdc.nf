
process GET_STUDY_ID {
    container 'mauraisa/pdc_client:latest'

    input:
        val pdc_study_id

    output:
        stdout

    shell:
    '''
    PDC_client studyID !{pdc_study_id}
    '''
}

process GET_STUDY_METADATA {
    container 'mauraisa/pdc_client:latest'
    
    input:
        val pdc_study_id

    output:
        path('study_metadata.tsv'), emit: metadata
        path('study_metadata_annotations.csv'), emit: skyline_annotations

    shell:
    '''
    PDC_client metadata -f tsv --nFiles !{params.n_raw_files} --skylineAnnotations !{pdc_study_id}
    '''
}

process GET_FILE {
    container 'mauraisa/pdc_client:latest'
    
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

