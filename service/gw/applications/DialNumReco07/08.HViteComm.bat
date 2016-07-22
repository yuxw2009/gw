.\HCopy -C fea_extract.cfg -S reco_extract_filelist.txt
.\HVite -T 1 -H models/hmm8/hmmdefs -S reco_filelist.txt -i rec_out.txt -w net.txt word_to_syllable_sp.dic lists\hmmlist.txt
rem type rec_out.txt
pause