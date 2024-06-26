#!/usr/bin/env bash

SCRIPT_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
  pwd -P
)

readonly VALID_TASKS=("all db_install db_setup tools_install tools_setup fusioncatcherdb ref example install_gatk install_gatk4 install_annovar")

function join_by { local IFS="$1"; shift; echo "$*"; }

function usage() {
  echo "usage: setup -t task"
  echo "  -t  task            specify task: $(join_by ' ' ${VALID_TASKS})"
  echo "  -h                  show this help screen"
  echo "  -m  file            Path to including filename of MSigDB hallmarks gene-set h.all.vX.X.entrez.gmt file"
  exit 1
}

while getopts d:t:m:ph option; do
  case "${option}" in
  d) readonly PARAM_DIR_PATIENT=$OPTARG ;;
  t) PARAM_TASK=$OPTARG ;;
  m) readonly HALLMARKS=$OPTARG ;;
  h) usage ;;
  \?)
    echo "Unknown option: -$OPTARG" >&2
    exit 1
    ;;
  :)
    echo "Missing option argument for -$OPTARG" >&2
    exit 1
    ;;
  *)
    echo "Unimplemented option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# if no patient is defined
if [[ -z "${PARAM_TASK}" ]]; then
  PARAM_TASK='all'
fi


if [[ ! " ${VALID_TASKS[@]} " =~ " ${PARAM_TASK} " ]]; then
  echo "unknown task: ${PARAM_TASK}"
  echo "use one of the following values: $(join_by ' ' ${VALID_TASKS})"
  exit 1
fi

[[ -z "$(which wget)" ]] && exit 1

readonly DIR_TOOLS="${SCRIPT_PATH}/tools"
readonly DIR_DATABASES="${SCRIPT_PATH}/databases"
readonly DIR_ASSETS="${SCRIPT_PATH}/assets"

readonly DIR_INPUT="${DIR_ASSETS}/input"
readonly DIR_REF="${DIR_ASSETS}/references"

readonly DIR_SEQUENCING="${DIR_REF}/sequencing"

# direct download of any file from gdrive
# https://stackoverflow.com/questions/25010369/wget-curl-large-file-from-google-drive/49444877#49444877
function curlgdrive() {
  [[ -z "$(which curl)" ]] && exit 1

  local fileid="${1}"
  local filename="${2}"
  local cookiefile="cookie-${fileid}"
  local uuid_file="google_uuid.txt"

  # download file using cookie information
  wget --save-cookies "${SCRIPT_PATH}/${cookiefile}" "https://docs.google.com/uc?export=download&id=${fileid}" -O- | sed -rn 's/.*name="uuid" value=\"([0-9A-Za-z_\-]+).*/\1/p' > ${uuid_file}
  wget --load-cookies "${SCRIPT_PATH}/${cookiefile}" -O ${filename} "https://drive.usercontent.google.com/download?export=download&id=${fileid}&confirm=t&uuid="$(<google_uuid.txt)

  # cleanup
  rm -f "${SCRIPT_PATH}/${cookiefile}"
  rm -f ${uuid_file}
}

# example
######################################################################################
function setup_example() {
  echo "setting up example data"

  curlgdrive "1gcCmsqJpbMsLSLmRfo3Afc_aTJVX7ziK" Capture_Regions.tar.gz
  curlgdrive "1YQLyUtkZALZ5Bv-MTvEJJOXAOT_R59Z7" data.tar.gz

  tar -xzf Capture_Regions.tar.gz -C "${DIR_SEQUENCING}" && rm -f Capture_Regions.tar.gz
  tar -xzf data.tar.gz -C "${DIR_INPUT}" && rm -f data.tar.gz

  echo "done"
}


# REF
######################################################################################
function setup_references() {
  echo "setting up reference data"

  curlgdrive "1QZSkniYbI1cWWj8CA6-FS93ViiAn8z_G" chromosomes.tar.gz
  curlgdrive "1rSC-IuRYhdVvulo2yrSkHSBgVAo4iRt0" genome.tar.gz
  curlgdrive "1w8PL_J6k0X96W6IkXkjOOi_VnsDaaw8U" mappability.tar.gz

  tar -xzf chromosomes.tar.gz -C "${DIR_REF}" && rm -f chromosomes.tar.gz
  tar -xzf genome.tar.gz -C "${DIR_REF}" && rm -f genome.tar.gz
  tar -xzf mappability.tar.gz -C "${DIR_REF}/mappability" && rm -f mappability.tar.gz

  echo "done"
}


# TOOLS
######################################################################################
# Versions
readonly VERSION_GATK3="3.8-1-0-gf15c1c3ef"
readonly VERSION_GATK4="4.2.4.0"

########
# GATK #
########
function install_tool_gatk() {
  echo "installing tool gatk3"
  cd "${DIR_TOOLS}" || exit 1

  echo "fetching gatk"
  # download new version
  wget "https://storage.googleapis.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-${VERSION_GATK3}.tar.bz2" \
      -O gatk.tar.bz2

  # unpack
  tar xjf gatk.tar.bz2
  rm -f gatk.tar.bz2

  # rename folder and file (neglect version information)
  mv GenomeAnalysisTK*/* gatk/
  rm -rf GenomeAnalysisTK*

  echo "done"
}

#########
# GATK4 #
#########
function install_tool_gatk4() {
  echo "installing tool gatk4"
  cd "${DIR_TOOLS}" || exit 1

  echo "fetching gatk"
  # download new version
  wget "https://github.com/broadinstitute/gatk/releases/download/${VERSION_GATK4}/gatk-${VERSION_GATK4}.zip" \
      -O gatk4.zip

  # unpack
  unzip -o gatk4.zip
  rm -f gatk4.zip

  # rename folder and file (neglect version information)
  mv gatk-4*/* gatk4/
  rm -rf gatk-4*

  echo "done"
}

###########
# annovar #
###########
function install_tool_annovar() {
  echo "installing tool annovar"

  cd "${DIR_TOOLS}" || exit 1

  echo "please visit https://www.openbioinformatics.org/annovar/annovar_download_form.php to get the download link for annovar via an email"
  echo "enter annovar download link:"
  read -r url_annovar

  echo "fetching annovar"
  wget "${url_annovar}" \
      -O annovar.tar.gz

  # unpack
  tar -xzf annovar.tar.gz
  rm -f annovar.tar.gz

  cd annovar

  echo "done"
}

function setup_tool_annovar() {
  echo "setup tool annovar"
  echo "download databases"

  cd "${DIR_TOOLS}/annovar" || exit 1

  # Download proposed databases directly from ANNOVAR
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar refGene humandb/
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar dbnsfp42a humandb/
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar gnomad211_genome humandb/
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar avsnp150 humandb/
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar clinvar_20210501 humandb/
  ./annotate_variation.pl -buildver hg19 -downdb -webfrom annovar intervar_20180118 humandb/

  echo "done"
}

function setup_tool_fusioncatcher() {
  echo "setup tool fusioncatcher"
  echo "download database"

  mkdir -p "${DIR_TOOLS}/fusioncatcher/data"
  cd "${DIR_TOOLS}/fusioncatcher/data" || exit 1
  wget --no-check-certificate http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.aa -O human_v102.tar.gz.aa
  wget --no-check-certificate http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ab -O human_v102.tar.gz.ab
  wget --no-check-certificate http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ac -O human_v102.tar.gz.ac
  wget --no-check-certificate http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ad -O human_v102.tar.gz.ad
  wget --no-check-certificate http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.md5 -O human_v102.md5
  md5sum -c human_v102.md5
  if [ "$?" -ne "0" ]; then
    echo -e "\n\n\n\033[33;7m   ERROR: The downloaded files from above have errors! MD5 checksums do not match! Please, download them again or re-run this script again!   \033[0m\n"
    exit 1
  fi

  cat human_v102.tar.gz.* > human_v102.tar.gz
  rm -f human_v102.tar.gz.*

  tar -xzf human_v102.tar.gz
  ln -s human_v102 current

  rm -f human_v102.tar.gz
  rm -f human_v102.md5
  echo "done"
}

# databases
######################################################################################
function install_databases() {
  echo "installing databases"

  cd "${DIR_DATABASES}" || exit 1

  # dbSNP
  wget https://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b150_GRCh37p13/VCF/All_20170710.vcf.gz -O "dbSNP/snp150hg19.vcf.gz"
  wget https://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b150_GRCh37p13/VCF/All_20170710.vcf.gz.tbi -O "dbSNP/snp150hg19.vcf.gz.tbi"
 
  # Cancer Hotspots
  wget http://www.cancerhotspots.org/files/hotspots_v2.xls

  # DGIdb
  wget https://www.dgidb.org/data/monthly_tsvs/2020-Oct/interactions.tsv -O DGIdb_interactions.tsv

  echo "done"
}

function setup_databases() {
  echo "setup databases"

  if [[ -z "${HALLMARKS}" ]]; then
    echo "no hallmarks file provided! Please provide the h.all.vX.X.entrez.gmt file from MSigDB."
    exit 1
  fi
  echo "${HALLMARK}"

  cd "${DIR_DATABASES}" || exit 1

  BIN_RSCRIPT=$(which Rscript)
  if [[ -z "${BIN_RSCRIPT}" ]]; then
    echo "Rscript needs to be available and in PATH in order to install the databases"
    exit 1
  fi

  ## R Code for processing
  ${BIN_RSCRIPT} --vanilla geneset_generation.R "${HALLMARKS}"

  echo "done"
}

case "${PARAM_TASK}" in
  "tools_install") 
    install_tool_gatk
    install_tool_gatk4
    install_tool_annovar
  ;;

  "install_gatk")
    install_tool_gatk
  ;;

  "install_gatk4")
    install_tool_gatk4
  ;;

  "install_annovar")
    install_tool_annovar
  ;;

  "db_install") 
    install_databases
  ;;

  "db_setup")
    setup_databases
  ;;

  "tools_setup")
    setup_tool_annovar
  ;;

  "fusioncatcherdb")
    setup_tool_fusioncatcher
  ;;

  "ref")
    setup_references
  ;;

  "example")
    setup_example
  ;;

  *) 
    install_tool_gatk
    install_tool_gatk4
    install_tool_annovar
    setup_tool_annovar

    install_databases
    setup_databases

    setup_references
    setup_example

  ;;
esac
