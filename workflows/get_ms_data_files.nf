// modules
include { PANORAMA_GET_RAW_FILE } from "../modules/panorama"
include { PANORAMA_GET_RAW_FILE_LIST } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"

workflow get_mzml_files {

    emit:
        mzml_ch

    take:
        ms_file_dir
        ms_file_glob
        ms_file_ext

    main:

        if(ms_file_dir.contains("https://")) {

            spectra_dirs_ch = Channel.from(ms_file_dir)
                                    .splitText()               // split multiline input
                                    .map{ it.trim() }          // removing surrounding whitespace
                                    .filter{ it.length() > 0 } // skip empty lines

            // get raw files from panorama
            PANORAMA_GET_RAW_FILE_LIST(spectra_dirs_ch, ms_file_glob, ms_file_ext)

            placeholder_ch = PANORAMA_GET_RAW_FILE_LIST.out.raw_file_placeholders.transpose()
            PANORAMA_GET_RAW_FILE(placeholder_ch)
            mzml_ch = PANORAMA_GET_RAW_FILE.out.panorama_file
            
            if(ms_file_ext == 'mzML') {
                narrow_mzml_ch = PANORAMA_GET_RAW_FILE.out.panorama_file
                return
            }
            if (ms_file_ext == 'raw') {
                narrow_mzml_ch = MSCONVERT(
                    PANORAMA_GET_RAW_FILE.out.panorama_file,
                    params.msconvert.do_demultiplex,
                    params.msconvert.do_simasspectra
                )
                return
            }

        } else {

            file_glob = ms_file_glob
            spectra_dir = file(ms_file_dir, checkIfExists: true)
            data_files = file("$spectra_dir/${file_glob}")

            if(data_files.size() < 1) {
                error "No files found for: $spectra_dir/${file_glob}"
            }

            mzml_files = data_files.findAll { it.name.endsWith('.mzML') }
            raw_files = data_files.findAll { it.name.endsWith('.raw') }

            if(mzml_files.size() < 1 && raw_files.size() < 1) {
                error "No raw or mzML files found in: $spectra_dir"
            }

            if(mzml_files.size() > 0 && raw_files.size() > 0) {
                error "Matched raw files and mzML files for: $spectra_dir/${file_glob}. Please choose a file matching string that will only match one or the other."
            }

            if(mzml_files.size() > 0) {
                mzml_ch = Channel.fromList(mzml_files)
            } else {
                mzml_ch = MSCONVERT(
                    Channel.fromList(raw_files),
                    params.msconvert.do_demultiplex,
                    params.msconvert.do_simasspectra
                )
            }
        }
}
