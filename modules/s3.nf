
process GET_DOCKER_INFO {
    publishDir "${params.result_dir}/s3", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'mauraisa/s3_client:0.6'

    output:
        path('docker_info.txt'), emit: info_file
        env GIT_HASH, emit: git_hash
        env GIT_SHORT_HASH, emit: git_short_hash
        env GIT_UNCOMMITTED_CHANGES, emit: git_uncommitted_changes
        env GIT_LAST_COMMIT, emit: git_last_commit
        env DOCKER_TAG, emit: docker_tag

    shell:
        '''
        echo -e "GIT_HASH=${GIT_HASH}" > docker_info.txt
        echo -e "GIT_SHORT_HASH=${GIT_SHORT_HASH}" >> docker_info.txt
        echo -e "GIT_UNCOMMITTED_CHANGES=${GIT_UNCOMMITTED_CHANGES}" >> docker_info.txt
        echo -e "GIT_LAST_COMMIT=${GIT_LAST_COMMIT}" >> docker_info.txt
        echo -e "DOCKER_TAG=${DOCKER_TAG}" >> docker_info.txt
        '''
}

process UPLOAD_FILE {
    label 'process_low_constant'
    container 'mauraisa/s3_client:0.6'
    publishDir "${params.result_dir}/s3", failOnError: true, mode: 'copy'

    input:
        val bucket_name
        val access_key
        val destination_path
        path file_to_upload

    output:
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        """
        s3_client -b "${bucket_name}" \
            -k "${access_key}" \
            -s \$S3_SECRET_ACCESS_KEY \
            put --verbose \
            "${file_to_upload}" "${destination_path}" \
            > >(tee "s3_upload_file-${file_to_upload.baseName}.stdout") \
              2> >(tee "s3_upload_file-${file_to_upload.baseName}.stderr" >&2)
        """

    stub:
    """
    touch stub.stdout stub.stderr
    """
}

process UPLOAD_MANY_FILES {
    label 'process_high_memory'
    container 'mauraisa/s3_client:0.6'
    publishDir "${params.result_dir}/s3", failOnError: true, mode: 'copy'

    input:
        val bucket_name
        val access_key
        val destination_path
        path files_to_upload

    output:
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        files = "${(files_to_upload as List).collect{ file(it).name }.join(' ')}"
        """
        echo ${files}
        s3_client -b "${bucket_name}" \
            -k "${access_key}" \
            -s \$S3_SECRET_ACCESS_KEY \
            put --verbose \
            ${files} \
            "${destination_path}"

        cp -v .command.err "s3_upload_file.stderr"
        cp -v .command.out "s3_upload_file.stdout"
        """

    stub:
    """
    touch stub.stdout stub.stderr
    """
}

