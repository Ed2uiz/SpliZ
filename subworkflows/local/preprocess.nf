include { CONVERT_SPLIT_PARQUET     } from './../../modules/local/convert_split_parquet'
include { CONVERT_PARQUET           } from './../../modules/local/convert_parquet'
include { CONVERT_BAM               } from './convert_bam'

workflow PREPROCESS {

    main:

    // Prepare inputs from SICILIAN output files
    if (params.SICILIAN) {   
        // Stage input file   
        input_file = file(params.input_file)
        
        // Check if input file type is valid, throw error if invalid
        def is_valid_input_file = input_file.extension in ["tsv", "pq", "txt"]
        if (!is_valid_input_file) {
            exit 1, "Invalid input file type supplied, options are *.pq, *.txt, or *.tsv."
        } else { 
            // Initalize input channel
            ch_input = Channel.fromPath(params.input_file)
            
            // Initialize parquet channel for SICILIAN tsv
            if (input_file.extension == "tsv" || input_file.extension == "txt") {
                CONVERT_SPLIT_PARQUET (
                    ch_input
                )
                ch_pq = CONVERT_SPLIT_PARQUET.out.pq   
            // Initialize parquet channel for SICILIAN pq
            } else if (input_file.extension == "pq") {
                ch_pq = ch_input        
            }
        }

    // Prepare inputs from non-SICILIAN bam files
    } else {
        // Initialize bam channel for bams stored in one directory
        if (params.bam_method == "directory") {
            ch_bam = Channel.fromPath("${params.bam_dir}/*.bam")
                .map { it ->
                    tuple ( it.baseName, it )
                }
        } 

        // Initialize bam channel for bams specified in samplesheet
        if (params.bam_method == "samplesheet") {

            // Initialize bam channel for 10X bams specified in samplesheet
            if (params.libraryType == "10X") {
                ch_bam = Channel.fromPath(params.bam_samplesheet)
                    .splitCsv(header:false)
                    .map { row ->
                        tuple( 
                            row[0],         // bam file sample_ID
                            file(row[1])    // bam file R1 path 
                        )
                    }   
            // Initialize bam channel for SS2 bams specified in samplesheet       
            } else if (params.libraryType == "SS2") {
                ch_bam = Channel.fromPath(params.bam_samplesheet)
                    .splitCsv(header:true)
                    .map { row ->
                        tuple( 
                            row[0],         // bam file sample_ID
                            file(row[1]),   // bam file R1 path 
                            file(row[2])    // bam file R2 path
                        )
                    }       
            }
        }

        // Check that bam channel has contents
        //ch_bam.ifEmpty{ exit 1, "No bam files found, please check inputs" }

        // Preprocess bam files for SpliZ pipeline
        CONVERT_BAM (
            ch_bam
        )

        // Initialize parquet channel for non-SICILIAN bam files
        ch_pq = CONVERT_BAM.out.pq
    }

    emit:
    pq = ch_pq

}