function IntensityNormalize(imageNames,referenceName,prefix,methodID,d)

% Two intensity standardization methods: mean method and median method.

    n = length(imageNames);
    refName = referenceName{1};
    for i=1:n
        V = spm_vol(imageNames{i});
        img = spm_read_vols(V);
        img(isnan(img)) = 0;
    
        mask = resampleImgToRef(refName, imageNames{i}, 'nearest');
        mask(isnan(mask)) = 0;
        mask = mask > 0.9;   
    
        tImg = img(mask);
        if methodID == 1
            normFactor = mean(tImg);
        elseif methodID == 2
            normFactor = median(tImg);
        end
        img = img / normFactor;
        [filepath, name, ext] = fileparts(V.fname);
        V.fname = fullfile(filepath, [prefix, name, ext]);
        V.dt = [16, 0];
        spm_write_vol(spm_create_vol(V), img);
        d.Value = i/n;
    end
    
end