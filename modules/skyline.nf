def check_max_mem(obj) {
    try {
        if (obj.compareTo(params.max_memory as nextflow.util.MemoryUnit) == 1)
            return (params.max_memory as nextflow.util.MemoryUnit) - 1.Gb
        else
            return obj
    } catch (all) {
        println "   ### ERROR ###   Max memory '${params.max_memory}' is not valid! Using default value: $obj"
        return obj
    }
}

process GET_VERSION {
    publishDir "${params.result_dir}/skyline", failOnError: true, mode: 'copy'
    label 'process_low'
    container "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758"

    output:
        path("pwiz_versions.txt"), emit: info_file

    shell:
    '''
    wine SkylineCmd --version > version.txt

    # parse Skyline version info
    vars=($(cat version.txt | \
            tr -cd '\\11\\12\\15\\40-\\176' | \
            egrep -o 'Skyline.*' | \
            sed -E "s/(Skyline[-a-z]*) \\((.*)\\) ([.0-9]+) \\(([A-Za-z0-9]{7})\\)/\\1 \\3 \\4/"))
    skyline_build="${vars[0]}"
    skyline_version="${vars[1]}"
    skyline_commit="${vars[2]}"

    # parse msconvert info
    msconvert_version=$(cat version.txt | \
                        tr -cd '\\11\\12\\15\\40-\\176' | \
                        egrep -o 'Proteo[a-zA-Z0-9\\. ]+' | \
                        egrep -o [0-9].*)

    echo "skyline_build=${skyline_build}" > pwiz_versions.txt
    echo "skyline_version=${skyline_version}" >> pwiz_versions.txt
    echo "skyline_commit=${skyline_commit}" >> pwiz_versions.txt
    echo "msconvert_version=${msconvert_version}" >> pwiz_versions.txt
    '''
}

process SKYLINE_ADD_LIB {
    publishDir "${params.result_dir}/skyline/add-lib", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    label 'process_medium'
    label 'error_retry'
    container "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:${params.skyline.docker_version}"

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
    // publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy', enabled: params.skyline.save_intermediate_output
    // label 'process_medium'
    memory 30.GB
    cpus 4
    time 8.h
    label 'error_retry'
    container "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758"
    stageInMode "${workflow.profile == 'aws' ? 'symlink' : 'link'}"

    input:
        path skyline_zipfile
        path mzml_file

    output:
        path("*.skyd"), emit: skyd_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:

    if( workflow.profile == 'aws' ) 
    """
    unzip ${skyline_zipfile}

    cp ${mzml_file} /tmp/${mzml_file}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --import-file="/tmp/${mzml_file}" \
    > >(tee 'import_${mzml_file.baseName}.stdout') 2> >(tee 'import_${mzml_file.baseName}.stderr' >&2)
    """

    else
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --import-file="${mzml_file}" \
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
    cpus 16
    memory { check_max_mem(1.GB * skyd_files.size()) } // Allocate 1 GB of RAM per mzml file
    time 8.h
    label 'error_retry'
    container "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758"

    input:
        path skyline_zipfile
        path skyd_files
        path mzml_files
        path fasta

    output:
        path("*.sky.zip"), emit: final_skyline_zipfile
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    if( params.skyline.minimize == false )
        """
        unzip ${skyline_zipfile}

        wine SkylineCmd \
            --in="${skyline_zipfile.baseName}" \
            --import-fasta="${fasta}" \
            --import-file="${(mzml_files as List).collect{ "/tmp/" + file(it).name }.join('" --import-file="')}" \
            ${params.skyline.protein_group_args} \
            --out="final.sky" \
            --save \
            --share-zip="final.sky.zip" \
            --share-type="complete" \
        > >(tee 'merge_skyline.stdout') 2> >(tee 'merge_skyline.stderr' >&2)
        """
    if( params.skyline.minimize == true )
        """
        unzip ${skyline_zipfile}

        wine SkylineCmd \
            --in="${skyline_zipfile.baseName}" \
            --import-fasta="${fasta}" \
            --import-file="${(mzml_files as List).collect{ "/tmp/" + file(it).name }.join('" --import-file="')}" \
            ${params.skyline.protein_group_args} \
            --out="final_minimized.sky" \
            --save \
            --chromatograms-discard-unused \
            --chromatograms-limit-noise=1 \
            --share-zip="final_minimized.sky.zip" \
            --share-type="minimal" \
        > >(tee 'merge_skyline.stdout') 2> >(tee 'merge_skyline.stderr' >&2)
        """
    else
        error "Unknown argument for params.skyline.minimize"

    stub:
    """
    touch final.sky.zip
    touch stub.stdout stub.stderr
    """
}

process UNZIP_SKY_FILE {
    label 'process_high_memory'
    container 'mauraisa/aws_bash:0.5'

    input:
        path(sky_zip_file)

    output:
        path("*.sky"), emit: sky_file
        path("*.{skyd,[eb]lib,[eb]libc,protdb,sky.view}"), emit: sky_artifacts
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
    publishDir "${params.result_dir}/skyline/annotate", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    stageInMode 'link'
    container 'proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758'

    input:
        path sky_file
        path sky_artifacts
        path annotation_csv

    output:
        path("final_annotated.sky.zip"), emit: sky_zip_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr
        env(sky_zip_hash), emit: file_hash
        env(sky_zip_size), emit: file_size

    shell:
    """
    wine SkylineCmd --in="${sky_file}" \
        --out="final_annotated.sky" \
        --import-annotations="${annotation_csv}" --save \
        --share-zip="final_annotated.sky.zip" \
    > >(tee 'annotate_doc.stdout') 2> >(tee 'annotate_doc.stderr' >&2)

    sky_zip_hash=\$( md5sum final_annotated.sky.zip |awk '{print \$1}' )
    sky_zip_size=\$( du -L final_annotated.sky.zip |awk '{print \$1}' )
    """

    stub:
    '''
    touch "final_annotated.sky.zip"
    touch stub.stdout stub.stderr
    sky_zip_hash=\$( md5sum final_annotated.sky.zip |awk '{print \$1}' )
    sky_zip_size=\$( du -L final_annotated.sky.zip |awk '{print \$1}' )
    '''
}

process SKYLINE_EXPORT_REPORT {
    publishDir "${params.result_dir}/skyline/reports", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    stageInMode 'link'
    container 'proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758'

    input:
        path sky_file
        path sky_artifacts
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
