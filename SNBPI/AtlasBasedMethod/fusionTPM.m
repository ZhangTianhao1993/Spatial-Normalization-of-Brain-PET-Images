function [newTPM,maxIndex] = fusionTPM(pwImg,psTPM)
    % Combine tTPM once to get a new TPM
    
    [~,TPMnum] = size(psTPM);
    muList = estimatePara(pwImg,psTPM);
    [sTPM,I] = sortTPM(psTPM,muList); 

    baselineLogL = computeLogLikelihood(pwImg,sTPM);

    maxIndex = zeros(2,1);
    maxdiffL = -inf;

    for i=1:TPMnum-1
        for n = 1:5
            j = i+n;
            if j<=TPMnum
                diffL = computeDiffL(pwImg,sTPM,i,j,baselineLogL);
                if diffL>= maxdiffL 
                    maxdiffL = diffL;
                    maxIndex = [I(i),I(j)];
                end
            end
        end
    end
    newTPM = psTPM;
    newTPM(:,maxIndex(1)) = psTPM(:,maxIndex(1))+psTPM(:,maxIndex(2));
    newTPM(:,maxIndex(2)) = [];
end

function muList = estimatePara(img,TPM)
    [~,TPMnum] = size(TPM);
    muList = zeros(TPMnum,1);
    for i=1:TPMnum
        TPMi = TPM(:,i);
        t = img.*TPMi;
        muList(i) = mean(t)/mean(TPMi);
    end
end
function [sTPM,I] = sortTPM(TPM,muList)
    [~,I] = sort(muList);
    [n,TPMnum] = size(TPM);
    sTPM = zeros(n,TPMnum);
    for i=1:TPMnum
        sTPM(:,i) = TPM(:,I(i));
    end
end
        