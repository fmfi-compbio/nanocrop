# nanocrop

This is a helper repository supporting a toolchain used for real-time monitoring of sequencing runs. The toolchain consists of [deepnano-blitz](https://github.com/fmfi-compbio/deepnano-blitz) basecaller used for MinKnow-compatible `.fastq` files production and [RAMPART](https://artic.network/rampart) for sequencing runs analysis. The repository contains RAMPART protocol and configuration for SARS-CoV-2 virus sequencing as well as some helper scripts. RAMPART protocol is slightly adjusted version of the one located [here](https://github.com/artic-network/artic-ncov2019), although another primer scheme using 2000bp long amplicons is provided in nanocrop and available for use.

## Toolchain installation

Install Miniconda package manager using system package manager: https://docs.conda.io/projects/conda/en/latest/user-guide/install/rpm-debian.html

Install Rust programming language:

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default nightly-2021-01-03
```

Install nanocrop helper repository:

```
git clone https://github.com/fmfi-compbio/nanocrop.git
cd nanocrop

conda env create -f environment.yml
conda activate nanocrop
```


Web browser needs to be installed on workstation performing RAMPART analysis.

## Toolchain execution

Toolchain will watch a designated input folder for `fast5` files being continuously created during sequencing run. For every `fast5` file `deepnano-blitz` basecaller is invoked. If more than one `fast5` file is created while basecaller was busy, next batch composed of those files will be processed in parallel assuming more than one CPU core is enabled for basecalling in configuration. Basecaller output is stored in `output folder`, which should be an input folder for the RAMPART pipeline at the same time. This is by default `rampart/SARS-CoV-2/SARS-CoV-2-400bp/data/fastq/pass/`. RAMPART will watch input folder configured for its pipeline and process any `fastq` files as they are created. Using its configuration and protocol RAMPART will demultiplex obtained reads and align them to the reference sequence provided. Thus monitoring current results of sequencing run such as reference genome coverage per barcoded sample in real time.

General toolchain parameters and basecaller parameters are specified in configuration file. Default configuration is stored in `config/run_configuration.cfg`. Rampart configuration is performed via its protocol and run configuration both found in rampart directory containing separate configuration per experiment.

Initialize the toolchain:

```
cd <nanocrop-project-dir>

conda activate nanocrop
./scripts/monitor-start.sh config/run_configuration.cfg
```

`monitor-start.sh` initializer starts the toolchain components in background and returns. To terminate the toolchain once experiment is over, run:

```
scripts/monitor-stop.sh
```

Visualization of sequencing-run monitoring is done by RAMPART graphical output and available at `http://localhost:3000`. 

Report issues at `<matej.fedor.mf@gmail.com>`.