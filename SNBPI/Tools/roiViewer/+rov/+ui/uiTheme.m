function C = uiTheme()
%ROV.UI.UITHEME  Return the viewer's colour and glyph theme.
%
% PURPOSE
%   Single source of truth for colours and optional Unicode glyphs.
%   Keeping the theme here lets every panel look consistent and makes
%   it easy to swap in an ASCII-only fallback on Linux systems whose
%   default fonts do not carry the fancy arrow glyphs.
%
% OUTPUT
%   C : struct with fields
%       .panel .ctrl .btn .scrollbtn .listbg .text .muted .accent
%       .glyph : struct with UI button glyphs
%                  .pageUp .pageDown .stepUp .stepDown .star .bullet
%
% NOTES
%   Set the environment variable ROV_ASCII_GLYPHS=1 (or edit the flag
%   below) to force ASCII glyphs on systems without the relevant font
%   coverage (some minimal Linux installs).
%
% EXAMPLE
%   C = rov.ui.uiTheme();
%   uibutton(parent,'Text',[C.glyph.pageUp ' Page Up']);

    C.panel     = [0.14 0.14 0.17];
    C.ctrl      = [0.22 0.22 0.26];
    C.btn       = [0.24 0.24 0.29];
    C.scrollbtn = [0.22 0.30 0.44];
    C.listbg    = [0.17 0.17 0.21];
    C.text      = [0.90 0.90 0.90];
    C.muted     = [0.55 0.55 0.60];
    C.accent    = [0.52 0.84 1.00];

    useAscii = strcmp(getenv('ROV_ASCII_GLYPHS'), '1');
    if useAscii
        C.glyph.pageUp   = '<<';
        C.glyph.pageDown = '>>';
        C.glyph.stepUp   = '^';
        C.glyph.stepDown = 'v';
        C.glyph.star     = '*';
        C.glyph.bullet   = '#';
    else
        C.glyph.pageUp   = char(9194);   %  fast-rewind triangle
        C.glyph.pageDown = char(9193);   %  fast-forward triangle
        C.glyph.stepUp   = char(8593);   %  up arrow
        C.glyph.stepDown = char(8595);   %  down arrow
        C.glyph.star     = char(9733);   %  black star
        C.glyph.bullet   = char(9632);   %  black square
    end
end
