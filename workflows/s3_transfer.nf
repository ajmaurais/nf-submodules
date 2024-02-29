// Modules
include { UPLOAD_MANY_FILES as UPLOAD_MZML_FILES } from "../modules/s3"
include { UPLOAD_MANY_FILES as UPLOAD_ENCYCLOPEDIA_SEARCH_FILES } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_QUANT_ELIB } from "../modules/s3"
include { UPLOAD_MANY_FILES as UPLOAD_SKYD_FILE } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_FINAL_SKYLINE_FILE } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_QC_REPORTS } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_FILE_CHECKSUMS } from "../modules/s3"
include { UPLOAD_FILE as UPLOAD_GENE_REPORTS } from "../modules/s3"
include { CALCULATE_FILE_STATS } from "../modules/s3"
include { WRITE_FILE_STATS } from "../modules/s3"

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

        // gene and precursor matricies
        gene_reports

    main:

        s3_directory = "/${params.s3_upload.prefix_dir == null ? '' : params.s3_upload.prefix_dir + '/'}${params.pdc_study_id}"

        // mzml_file_groups = mzml_files.collate(20)
        // UPLOAD_MZML_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                   "${s3_directory}/mzML/", mzml_file_groups)

        // encyclopedia_search_files_groups = encyclopedia_search_files.collate(20)
        // UPLOAD_ENCYCLOPEDIA_SEARCH_FILES(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                                  "${s3_directory}/encyclopedia/search_file/", encyclopedia_search_files_groups)

        // UPLOAD_QUANT_ELIB(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                   "${s3_directory}/encyclopedia/create_elib/", quant_elib)

        // UPLOAD_FINAL_SKYLINE_FILE(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                           "${s3_directory}/skyline/merge_results/", final_skyline_file)
        // 
        // UPLOAD_QC_REPORTS(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                   "${s3_directory}/qc_reports", qc_reports)

        // UPLOAD_QC_REPORTS(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                   "${s3_directory}/gene_reports", gene_reports)

        file_pairs = mzml_files.map{ it -> tuple("${s3_directory}/mzML", it) }.concat(
            encyclopedia_search_files.map{ it -> tuple("${s3_directory}/encyclopedia/search_file", it) }
        ).concat(
            quant_elib.map{ it -> tuple("${s3_directory}/encyclopedia/create_elib", it) }
        ).concat(
            final_skyline_file.map{ it -> tuple("${s3_directory}/skyline", it) }
        ).concat(
            qc_reports.map{ it -> tuple("${s3_directory}/qc_reports", it) }
        ).concat(
            workflow_versions.map{ it -> tuple("${s3_directory}", it) }
        ).concat(
            gene_reports.map{ it -> tuple("${s3_directory}/gene_reports", it) }
        )

        CALCULATE_FILE_STATS(file_pairs)
        file_paths = CALCULATE_FILE_STATS.out.map{ it[0] }
        file_names = CALCULATE_FILE_STATS.out.map{ it[1] }
        file_hashes = CALCULATE_FILE_STATS.out.map{ it[2] }
        file_sizes = CALCULATE_FILE_STATS.out.map{ it[3] }
        WRITE_FILE_STATS(file_paths.collect(), file_names.collect(),
                         file_hashes.collect(), file_sizes.collect())

        // UPLOAD_FILE_CHECKSUMS(params.s3_upload.bucket_name, params.s3_upload.access_key,
        //                       "${s3_directory}", WRITE_FILE_STATS.out)
}
