function std_out = strongStd(data, robustness_perc)
% Returns the std removing outliers (spikes)
%
% INPUT:
%   data                column array of values
%   robustness_perc     maximum percentage of date with no outliers
%
% SYNTAX:
%   std_out = strongStd(data, robustness_perc)

%--- * --. --- --. .--. ... * ---------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __|
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 1.0RC1
%
%--------------------------------------------------------------------------
%  Copyright (C) 2021 Geomatics Research & Development srl (GReD)
%  Written by:       Andrea Gatti
%  Contributors:     Andrea Gatti ...
%  A list of all the historical goGPS contributors is in CREDITS.nfo
%--------------------------------------------------------------------------
%
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
% 01100111 01101111 01000111 01010000 01010011
%--------------------------------------------------------------------------

    if nargin == 1
        robustness_perc = 0.8;
    end
    data_tmp = data - movmedian(data, 3, 'omitnan');
    thr1 = perc(abs(data_tmp), ceil(numel(data_tmp) * robustness_perc) / numel(data_tmp));
    id_ok = abs(data_tmp) < (6 * thr1);
    std_out = std(data(id_ok));
    id_ok = abs(data) < (6 * std_out);
    std_out = std(data(id_ok)) ;
end