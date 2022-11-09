#!/bin/bash
#
#make sure the following command has been executed
#bin/viash_build -q 'label_projection|common'

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

RAW_DATA=resources_test/common/pancreas/dataset.h5ad
DATASET_DIR=resources_test/label_projection/pancreas

if [ ! -f $RAW_DATA ]; then
    echo "Error! Could not find raw data"
    exit 1
fi

mkdir -p $DATASET_DIR

# subsample dataset
bin/viash run src/label_projection/data_processing/subsample/config.vsh.yaml -- \
    --input $RAW_DATA \
    --keep_celltype_categories "acinar:beta" \
    --keep_batch_categories "celseq:inDrop4:smarter" \
    --output $DATASET_DIR/dataset_subsampled.h5ad

# run one normalisation
bin/viash run src/label_projection/data_processing/normalize_log_cpm/config.vsh.yaml -- \
    --input $DATASET_DIR/dataset_subsampled.h5ad \
    --output $DATASET_DIR/dataset_subsampled_cpm.h5ad

# censor dataset
bin/viash run src/label_projection/data_processing/censoring/config.vsh.yaml -- \
    --input $DATASET_DIR/dataset_subsampled_cpm.h5ad \
    --output_train $DATASET_DIR/dataset_subsampled_cpm_train.h5ad \
    --output_test $DATASET_DIR/dataset_subsampled_cpm_test.h5ad \
    --output_solution $DATASET_DIR/dataset_subsampled_cpm_solution.h5ad \
    --seed 123

# run one method
bin/viash run src/label_projection/methods/knn_classifier/config.vsh.yaml -- \
    --input_train $DATASET_DIR/dataset_subsampled_cpm_train.h5ad \
    --input_test $DATASET_DIR/dataset_subsampled_cpm_test.h5ad \
    --output $DATASET_DIR/dataset_subsampled_cpm_prediction.h5ad

# run one metric
bin/viash run src/label_projection/metric/accuracy/config.vsh.yaml -- \
    --input_prediction $DATASET_DIR/dataset_subsampled_cpm_prediction.h5ad \
    --input_solution $DATASET_DIR/dataset_subsampled_cpm_solution.h5ad \
    --output $DATASET_DIR/dataset_subsampled_cpm_score.h5ad
