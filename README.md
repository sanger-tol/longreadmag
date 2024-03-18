[![Cite with Zenodo](https://zenodo.org/badge/509096312.svg)](https://zenodo.org/doi/10.5281/zenodo.10047653)
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/sanger-tol/longreadmag)

## Introduction

**sanger-tol/longreadmag** is a bioinformatics pipeline for the production of metagenome-assembled genomes.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

1. Parse input yaml ( YAML_INPUT )


## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
> with `-profile test` before running the workflow on actual data.

Currently, it is advised to run the pipeline with docker or singularity as a small number of major modules do not currently have a conda env associated with them.

Now, you can run the pipeline using:

```bash
# For the FULL pipeline
nextflow run main.nf -profile singularity --input {INPUT_YAML}.yaml --outdir {OUTDIR}

```

An example longreadmag.yaml can be found [here](assets/local_testing/longreadmag.yaml).

Further documentation about the pipeline can be found in the following files: [usage](https://pipelines.tol.sanger.ac.uk/longreadmag/dev/usage), [parameters](https://pipelines.tol.sanger.ac.uk/longreadmag/dev/parameters) and [output](https://pipelines.tol.sanger.ac.uk/longreadmag/dev/output).

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

sanger-tol/longreadmag has been written by William Eagles (@weaglesBio) and Noah Gettle (@weaglesBio).


## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!--TODO: Citation-->

<!-- If you use sanger-tol/longreadmag for your analysis, please cite it using the following doi: . -->

### Tools

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
