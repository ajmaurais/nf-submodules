// Modules
include { UPLOAD_MANY_FILES as UPLOAD_MZML_FILES } from "../modules/s3"
include { UPLOAD_MANY_FILES as UPLOAD_ENCYCLOPEDIA_SEARCH_FILES } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_QUANT_ELIB } from "../modules/s3"
include { UPLOAD_MANY_FILES as UPLOAD_SKYD_FILE } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_FINAL_SKYLINE_FILE } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_QC_REPORTS } from "../modules/s3"

workflow s3_upload {

    take:
        // ENCYCLOPEDIA_SEARCH_FILE artifacts
        mzml_files

        encyclopedia_search_files

        // ENCYCLOPEDIA_CREATE_ELIB
        quant_elib

        // Skyline files
        final_skyline_file

        // Reports
        qc_reports

        // workflow versions
        workflow_versions

    main:

        s3_directory = "/${params.s3_upload.prefix_dir == null ? '' : params.s3_upload.prefix_dir + '/'}${params.pdc_study_id}"

        // mzml_file_groups = mzml_files.collate(20)
        // UPLOAD_MZML_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                   "${s3_directory}mzML/", mzml_file_groups)

        // encyclopedia_search_files_groups = encyclopedia_search_files.collate(20)
        // UPLOAD_ENCYCLOPEDIA_SEARCH_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                                  "${s3_directory}/encyclopedia/search_file/", encyclopedia_search_files_groups)

        UPLOAD_QUANT_ELIB(params.s3_upload.bucket_name, params.s3_upload.access_key,
                          "${s3_directory}/encyclopedia/create_elib/", quant_elib)

        UPLOAD_FINAL_SKYLINE_FILE(params.s3_upload.bucket_name, params.s3_upload.access_key,
                                  "${s3_directory}/skyline/merge_results/", final_skyline_file)
        
        UPLOAD_QC_REPORTS(params.s3_upload.bucket_name, params.s3_upload.access_key,
                          "${s3_directory}/qc_reports", qc_reports)
}
