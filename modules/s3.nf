
process UPLOAD_FILE {
    label 'process_low_constant'
    container 'mauraisa/s3_client:0.3'

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
            1>"s3_upload_file-${file_to_upload.baseName}.stdout" 2>"s3_upload_file-${file_to_upload.baseName}.stderr"
        """
}

process UPLOAD_MANY_FILES {
    label 'process_high_memory'
    container 'mauraisa/s3_client:0.3'

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
}

