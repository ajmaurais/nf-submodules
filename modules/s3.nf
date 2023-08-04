
process UPLOAD_FILE {
    label 'process_low_constant'
    container 'mauraisa/s3_client:0.2'

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
            "${file_to_upload}" "${destination_path}"
        """
}

