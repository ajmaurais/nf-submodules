def exec_java_command(mem, encyclopedia_version) {
    def xmx = "-Xmx${mem.toGiga()-1}G"
    return "java -Djava.aws.headless=true ${xmx} -jar /code/encyclopedia-${encyclopedia_version}-executable.jar"
}

process GET_VERSION {
    publishDir "${params.result_dir}/encyclopedia", failOnError: true, mode: 'copy'
    label 'process_low'
    container "quay.io/mauraisa/encyclopedia:${params.encyclopedia.version}"

    output:
        path('encyclopedia_version.txt'), emit: info_file

    shell:
        '''
        java -jar /code/encyclopedia-!{params.encyclopedia.version}-executable.jar --version > 'version.txt' || echo "encyclopedia_exit=$?"
        echo "encyclopedia_version=$(cat version.txt| awk '{print $4}')" > encyclopedia_version.txt
        '''
}

process ENCYCLOPEDIA_SEARCH_FILE {
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.stderr", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.stdout", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.elib", failOnError: true, mode: 'copy', enabled: params.encyclopedia.save_output
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.dia", failOnError: true, mode: 'copy', enabled: params.encyclopedia.save_output
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.features.txt", failOnError: true, mode: 'copy', enabled: params.encyclopedia.save_output
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.encyclopedia.txt", failOnError: true, mode: 'copy', enabled: params.encyclopedia.save_output
    publishDir "${params.result_dir}/encyclopedia/search-file", pattern: "*.encyclopedia.decoy.txt", failOnError: true, mode: 'copy', enabled: params.encyclopedia.save_output
    label 'process_high'
    // container 'quay.io/protio/encyclopedia:2.12.30'
    // container "mauraisa/encyclopedia:${params.encyclopedia.version}"
    container "quay.io/mauraisa/encyclopedia:${params.encyclopedia.version}"

    input:
        path mzml_file
        path fasta
        path spectra_library_file
        val encyclopedia_params

    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("${mzml_file}.elib", emit: elib)
        path("${mzml_file.baseName}.dia",  emit: dia)
        path("${mzml_file}.features.txt", emit: features)
        path("${mzml_file}.encyclopedia.txt", emit: results_targets)
        path("${mzml_file}.encyclopedia.decoy.txt", emit: results_decoys)
        

    script:
    """
    ${exec_java_command(task.memory, params.encyclopedia.version)} \\
        -numberOfThreadsUsed ${task.cpus} \\
        -i ${mzml_file} \\
        -f ${fasta} \\
        -l ${spectra_library_file} \\
        -percolatorVersion /usr/local/bin/percolator \\
        ${encyclopedia_params} \\
        > >(tee "encyclopedia-${mzml_file.baseName}.stdout") 2> >(tee "encyclopedia-${mzml_file.baseName}.stderr" >&2)
    """

    stub:
    """
    touch stub.stdout stub.stderr
    touch "${mzml_file}.elib"
    touch "${mzml_file.baseName}.dia"
    touch "${mzml_file}.features.txt"
    touch "${mzml_file}.encyclopedia.txt"
    touch "${mzml_file}.encyclopedia.decoy.txt"
    """
}

process ENCYCLOPEDIA_CREATE_ELIB {
    publishDir "${params.result_dir}/encyclopedia/create-elib", failOnError: true, mode: 'copy'
    label 'process_memory_high_constant'
    // container 'quay.io/protio/encyclopedia:2.12.30'
    container "quay.io/mauraisa/encyclopedia:${params.encyclopedia.version}"

    input:
        path search_elib_files
        path search_dia_files
        path search_feature_files
        path search_encyclopedia_targets
        path search_encyclopedia_decoys
        path fasta
        path spectra_library_file
        val align_between_runs
        val outputFilePrefix
        val encyclopedia_params

    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("${outputFilePrefix}-combined-results.elib", emit: elib)

    script:
    """
    find * -name '*\\.mzML\\.*' -exec bash -c 'mv \$0 \${0/\\.mzML/\\.dia}' {} \\;

    ${exec_java_command(task.memory, params.encyclopedia.version)} \\
        -numberOfThreadsUsed ${task.cpus} \\
        -libexport \\
        -o '${outputFilePrefix}-combined-results.elib' \\
        -i ./ \\
        ${align_between_runs ? '-a' : ''} \\
        -f ${fasta} \\
        -l ${spectra_library_file} \\
        -percolatorVersion /usr/local/bin/percolator \\
        ${encyclopedia_params} \\
        > >(tee "${outputFilePrefix}.stdout") 2> >(tee "${outputFilePrefix}.stderr" >&2)
    """

    stub:
    """
    touch stub.stdout stub.stderr
    touch "${outputFilePrefix}-combined-results.elib"
    """
}

process ENCYCLOPEDIA_BLIB_TO_DLIB {
    publishDir "${params.result_dir}/encyclopedia/convert-blib", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'process_high_memory'
    // container 'quay.io/protio/encyclopedia:2.12.30'
    container "quay.io/mauraisa/encyclopedia:${params.encyclopedia.version}"

    input:
        path fasta
        path blib

    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("${blib.baseName}.dlib"), emit: dlib

    script:
    """
    ${exec_java_command(task.memory, params.encyclopedia.version)} \\
        -numberOfThreadsUsed ${task.cpus} \\
        -convert \\
        -blibToLib \\
        -o "${blib.baseName}.dlib" \\
        -i "${blib}" \\
        -f "${fasta}" \\
        > >(tee "encyclopedia-convert-blib.stdout") 2> >(tee "encyclopedia-convert-blib.stderr" >&2)
    """

    stub:
    """
    touch stub.stdout stub.stderr
    touch "${blib.baseName}.dlib"
    """
}
