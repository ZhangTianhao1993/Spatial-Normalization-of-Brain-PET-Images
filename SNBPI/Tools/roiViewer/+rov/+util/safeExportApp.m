function ok = safeExportApp(fig, outPath)
%ROV.UTIL.SAFEEXPORTAPP  Export an entire uifigure with a getframe fallback.
%
% PURPOSE
%   exportapp() is the preferred way to snapshot a whole uifigure, but
%   it has had platform-specific bugs (Linux headless, some driver
%   configurations). This wrapper tries exportapp first and falls back
%   to getframe + imwrite if it fails.
%
% INPUTS
%   fig     : uifigure handle.
%   outPath : full path to the output image file.
%
% OUTPUT
%   ok : true on success (either method), false if both failed.
%
% EXAMPLE
%   rov.util.safeExportApp(fig, '/tmp/full.png');

    ok = false;
    try
        exportapp(fig, outPath);
        ok = true;
        return;
    catch
        % fall through to getframe fallback
    end
    try
        frame = getframe(fig);
        imwrite(frame.cdata, outPath);
        ok = true;
    catch
        ok = false;
    end
end
