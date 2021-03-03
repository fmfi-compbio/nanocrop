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

Toolchain will use `basecall_continuous_reads.sh` script to watch a designated input folder for `.fast5` files being continuously created during sequencing run. For every `.fast5` file `deepnano-blitz` basecaller is invoked. Basecaller parameters in the script are fixed and set rather for short basecalling times than output accuracy. Please adjust basecaller parameters in the script manually according to your needs. Basecaller output is stored in `output folder`, which should be also an input folder for RAMPART pipeline. This is by default `rampart/SARS-CoV-2/data/fastq/pass/`. RAMPART will watch input folder configured for its pipeline and process `.fastq` files as they are created. Using its configuration and protocol RAMPART will demultiplex obtained reads and align them to the reference sequence provided. Thus monitoring current results of sequencing run such as reference genome coverage in real time.

Start the basecaller watchdog:

```
cd <nanocrop-project-dir>

conda activate deepnano-blitz
./basecall_continuous_reads <input-directory> rampart/SARS-CoV-2/data/fastq/pass/
```

Start RAMPART analysis in new terminal window:

```
cd <nanocrop-project-dir>/rampart/SARS-CoV-2/data/

conda activate artic-rampart
rampart --protocol ../protocol/
```

RAMPART graphical output is available at `http://localhost:3000`. 

Now the toolchain is prepared for the sequencing run.