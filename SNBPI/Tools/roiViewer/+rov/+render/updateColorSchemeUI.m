function updateColorSchemeUI(fig)
%ROV.RENDER.UPDATECOLORSCHEMEUI  Enable/disable colour controls by atlas count.
%
% PURPOSE
%   When more than one atlas is loaded Continuous mode is not meaningful
%   (each atlas needs its own swatch), so the scheme is forced to
%   Discrete and the colormap dropdown is disabled. With a single atlas,
%   the colormap dropdown and the colorbar Min/Max edit fields are
%   enabled only when Continuous is selected.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Toggles Enable state of s.h.ddScheme, s.h.ddCmap, s.h.txtCbMin and
%   s.h.txtCbMax; may change s.colorScheme.
%
% EXAMPLE
%   rov.render.updateColorSchemeUI(fig);

    s = fig.UserData;
    if s.nAtlas > 1
        s.h.ddScheme.Value  = 'Discrete';
        s.h.ddScheme.Enable = 'off';
        s.h.ddCmap.Enable   = 'off';
        s.colorScheme       = 'Discrete';
        cbInputsOn          = false;
    else
        s.h.ddScheme.Enable = 'on';
        if strcmp(s.colorScheme, 'Continuous')
            s.h.ddCmap.Enable = 'on';
            cbInputsOn        = true;
        else
            s.h.ddCmap.Enable = 'off';
            cbInputsOn        = false;
        end
    end

    if isfield(s.h,'txtCbMin') && isvalid(s.h.txtCbMin)
        if cbInputsOn
            s.h.txtCbMin.Enable = 'on';
            s.h.txtCbMax.Enable = 'on';
        else
            s.h.txtCbMin.Enable = 'off';
            s.h.txtCbMax.Enable = 'off';
        end
    end

    fig.UserData = s;
end