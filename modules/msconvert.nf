
process MSCONVERT {
    storeDir "${params.mzml_cache_directory}/${params.msconvert.do_demultiplex}/${params.msconvert.do_simasspectra}"
    publishDir "${params.result_dir}/msconvert", pattern: "*.mzML", failOnError: true, mode: 'copy', enabled: params.msconvert.store_mzml
    label 'process_medium'
    label 'error_retry'
    container 'proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24054-2352758'

    input:
        path raw_file
        val do_demultiplex
        val do_simasspectra

    output:
        path("${raw_file.baseName}.mzML"), emit: mzml_file

    script:

    demultiplex_param = do_demultiplex ? '--filter "demultiplex optimization=overlap_only"' : ''
    simasspectra = do_simasspectra ? '--simAsSpectra' : ''

    """
    wine msconvert \
        ${raw_file} \
        -v \
        --zlib \
        --mzML \
        --ignoreUnknownInstrumentError \
        --64 ${simasspectra} ${demultiplex_param} \
        --filter "peakPicking true 1-" 
    """

    stub:
    """
    touch ${raw_file.baseName}.mzML
    """
}
