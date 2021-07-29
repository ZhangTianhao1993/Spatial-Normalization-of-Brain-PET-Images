function [newTPM,maxIndex] = fusionTPM(pwImg,psTPM)
    % 合并一次tTPM，得到新的TPM
    [~,TPMnum] = size(psTPM);
    newTPM = psTPM;
    muList = estimatePara(pwImg,psTPM);
    [sTPM,I] = sortTPM(psTPM,muList); 
    maxIndex = zeros(2,1);%记录指标下降最大的合并的index
    maxdiffL = computeDiffL(pwImg,psTPM,1,2)-100; %初始将前两个合并后指标的变化作为最大

    for i=1:TPMnum-1
        for n = 1:5
            j = i+n;
            if j<=TPMnum
                diffL = computeDiffL(pwImg,sTPM,i,j);
                if diffL>= maxdiffL %希望新的似然更大，也就是减小的更小
                    maxdiffL = diffL;
                    maxIndex = [I(i),I(j)];
                end
            end
        end
    end
    newTPM(:,maxIndex(1)) = psTPM(:,maxIndex(1))+psTPM(:,maxIndex(2));
    newTPM(:,maxIndex(2)) = [];
end

function muList = estimatePara(img,TPM)
    % 估计模型参数
    [~,TPMnum] = size(TPM);
    muList = zeros(TPMnum,1);
    for i=1:TPMnum
        TPMi = TPM(:,i);
        t = img.*TPMi;
        muList(i) = mean(t)/mean(TPMi); %加权平均
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
        