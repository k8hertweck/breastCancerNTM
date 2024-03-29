#!/bin/bash

## creating table of breast cancer data by individual

SCRIPT=`pwd`
WORK=~/Dropbox/cancerGenomics/breast

cd $WORK/processing/target_genes 

# rename for easier file inspection with spreadsheet program
rename 's/.tsv/.csv/' *.tsv

# make header
head -1 BC01.csv > header.txt

# create list of unique identifier for each individual
for x in *.csv
	do
		tail +2 $x | cut -f 6 | uniq | sed 's:\.:\\\.:g' > $x.dbsnp.lst
done

# extract first hit for each SNP from respective files
for x in `cat $SCRIPT/sampleNames.lst`
	do
		cat header.txt > $x.temp
			for snp in `cat $x.csv.dbsnp.lst`
				do
					grep -m 1 "\t$snp\t" $x.csv >> $x.temp
					cat $x.temp > $x.table
				done
done

# clean up
rename 's/.table/.table.csv/' *.table
# remove misfiltered indels
echo -n > BR07.table.csv
grep -v "GGCGGCGGCGGCGGCGGC" BR13.table.csv > temp
mv temp BR13.table.csv

# extract somatic variants (only in sputum)
# Ref/Het, Ref/Hom, Hom/Het, Hom/Ref
for x in `cat $SCRIPT/sampleNames.lst`
	do
		cat header.txt > $x.somatic.csv
		awk -F "\t" '{
			if ($18 == "Ref" && $21 == "Het") print $0; 
			else if ($18 == "Ref" && $21 == "Hom") print $0;
			else if ($18 == "Hom" && $21 == "Het") print $0;
			else if ($18 == "Hom" && $21 == "Ref") print $0;
			else next}' $x.table.csv > $x.somatic.csv
done

# extract germline variants (in both sputum and lymphocyte)
# Het/Hom, Het/Ref
for x in `cat $SCRIPT/sampleNames.lst`
	do
		cat header.txt > $x.germline.csv
		awk -F "\t" '{
			if ($18 == "Het" && $21 == "Hom") print $0; 
			else if ($18 == "Het" && $21 == "Ref") print $0;
			else next}' $x.table.csv > $x.germline.csv
done

# extract variants present only in germline (lymphocyte)
# Hom/Ref
for x in `cat $SCRIPT/sampleNames.lst`
	do
		cat header.txt > $x.remove.csv
		awk -F "\t" '{
			if ($18 == "Hom" && $21 == "Ref") print $0; 
			else next}' $x.table.csv > $x.remove.csv
done

# aggregate somatic variants among samples
echo -n > breastTable.somatic.csv.temp
for x in `cat $SCRIPT/sampleNames.lst`
	do
		echo -e '\n'$x >> breastTable.somatic.csv.temp
		cut -f 1,2,4,5,6,8,9,10 $x.somatic.csv >> breastTable.somatic.csv.temp
done
		
sed s/.csv.table//g breastTable.somatic.csv.temp | 
	sed s/_variant//g |
	sed s/snpEffEffect/type/g |
	sed s/snpEffHGVS/mutation/g |
	sed s/ref/reference/g |
	sed s/alt/variant/ |
	sed s/dbsnp/dbSNP/ |
	sed s/start/position/ |
	sed 's/\/c.*$//' |
	sed 's/NM_.*:p\.//' |
	sed -E 's/([A-Z]{1}[a-z]{2})[0-9]{1,4}/\1\>/g' |
	sed -E 's/[A-Z][a-z]{2}\>_.*$//' |
	awk '{print $1,$6,$2,$7,$3,$4,$8,$5}' |
	sed 's/,\.,/,NA,/g' > breastTable.somatic.csv

# create file with just nonsynonymous somatic variants (used in publication)
grep -v synonymous breastTable.somatic.csv > breastTable.somatic.nonsyn.csv

# create files with all somatic variants by gene
echo -n somaticVariants.csv
for gene in `cat $SCRIPT/BCgenes.lst`
	do
		echo $gene >> somaticVariants.csv
		grep " $gene " breastTable.somatic.nonsyn.csv >> somaticVariants.csv
done

# aggregate germline variants among all samples for BRCA1 and BRCA1
echo -n > breastTable.germline.csv.temp
for x in `cat $SCRIPT/sampleNames.lst`
	do
		echo -e '\n'$x >> breastTable.germline.csv.temp
		cut -f 1,2,4,5,6,8,9,10 $x.germline.csv >> breastTable.germline.csv.temp
done
		
sed s/.csv.table//g breastTable.germline.csv.temp | 
	sed s/_variant//g |
	sed s/snpEffEffect/type/g |
	sed s/snpEffHGVS/mutation/g |
	sed s/ref/reference/g |
	sed s/alt/variant/ |
	sed s/dbsnp/dbSNP/ |
	sed s/start/position/ |
	sed 's/\/c.*$//' |
	sed 's/NM_.*:p\.//' |
	sed -E 's/([A-Z]{1}[a-z]{2})[0-9]{1,4}/\1\>/g' |
	sed -E 's/[A-Z][a-z]{2}\>_.*$//' |
	awk '{print $1,$6,$2,$7,$3,$4,$8,$5}' |
	sed 's/,\.,/,NA,/g' > breastTable.germline.csv

# create file with just nonsynonymous germline variants (used in publication)
grep -v synonymous breastTable.germline.csv > breastTable.germline.nonsyn.csv

# create files with all germline variants by gene
echo -n germlineVariants.csv
for gene in `cat $SCRIPT/BCgenes.lst`
	do
		echo $gene >> germlineVariants.csv
		grep " $gene " breastTable.germline.nonsyn.csv >> germlineVariants.csv
done

# create file with deletions
echo -n geneDeletions.csv
for x in `cat $SCRIPT/sampleNames.lst`
	do
		grep deletion $x.csv >> geneDeletions.csv
done

# create file for gene figures that includes germline and somatic mutations
echo "SOMATIC" > geneFigs.csv
grep "missense_variant" breastTable.somatic.csv.temp | sort -k 6 | uniq -c | sort -k 7 >> geneFigs.csv

echo "GERMLINE" >> geneFigs.csv
grep "missense_variant" breastTable.germline.csv.temp | sort -k 6 | uniq -c | sort -k 7 >> geneFigs.csv
