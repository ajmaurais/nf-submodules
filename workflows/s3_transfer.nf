// Modules
include {UPLOAD_FILE as UPLOAD_MZML_FILES } from "../modules/s3"
include {UPLOAD_FILE as UPLOAD_ENCYCLOPEDIA_SEARCH_FILES } from "../modules/s3"
include {UPLOAD_FILE as UPLOAD_QUANT_ELIB } from "../modules/s3"
include {UPLOAD_FILE as UPLOAD_SKYD_FILE } from "../modules/s3"
include {UPLOAD_FILE as UPLOAD_FINAL_SKYLINE_FILE } from "../modules/s3"
include {UPLOAD_FILE as UPLOAD_QC_REPORTS } from "../modules/s3"

workflow s3_upload {

    take:
        // ENCYCLOPEDIA_SEARCH_FILE artifacts
        mzml_files

        encyclopedia_search_files

        // ENCYCLOPEDIA_CREATE_ELIB
        quant_elib

        // Skyline files
        skyd_files
        final_skyline_file

        // Reports
        qc_reports
        

    main:
         
        UPLOAD_MZML_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/mzML/", mzml_files)

        UPLOAD_ENCYCLOPEDIA_SEARCH_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/encyclopedia/search_file/", encyclopedia_search_files)

        UPLOAD_QUANT_ELIB(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/encyclopedia/create_elib/", quant_elib)

        UPLOAD_SKYD_FILE(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/skyline/import_spectra/", skyd_files)
        UPLOAD_FINAL_SKYLINE_FILE(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/skyline/merge_results/", final_skyline_file)
        
        UPLOAD_QC_REPORTS(params.s3_upload.bucket_name, params.s3_upload.access_key, "/${params.pdc_study_id}/qc_reports", qc_reports)
}
