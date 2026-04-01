function nmi = compute_nmi(vol1, vol2, mask, nBins)
    % vol1, vol2 : 三维图像矩阵（double）
    % mask       : 脑掩膜（逻辑矩阵），可选
    % nBins      : 直方图bins数，默认64

    if nargin < 3 || isempty(mask)
        mask = true(size(vol1));
    end
    if nargin < 4
        nBins = 64;
    end

    % 提取掩膜内体素
    a = double(vol1(mask));
    b = double(vol2(mask));

    % 归一化到 [0, 1]
    a = (a - min(a)) / (max(a) - min(a) + eps);
    b = (b - min(b)) / (max(b) - min(b) + eps);

    % 计算联合直方图
    edges = linspace(0, 1, nBins + 1);
    H = histcounts2(a, b, edges, edges);

    % 防止 log(0)
    H = H + eps;
    H = H / sum(H(:));

    % 边缘分布
    Ha = sum(H, 2);
    Hb = sum(H, 1);

    % 计算熵
    entropy_a  = -sum(Ha(Ha > 0) .* log2(Ha(Ha > 0)));
    entropy_b  = -sum(Hb(Hb > 0) .* log2(Hb(Hb > 0)));
    entropy_ab = -sum(H(H   > 0) .* log2(H(H   > 0)));

    % NMI
    nmi = (entropy_a + entropy_b) / entropy_ab;
end