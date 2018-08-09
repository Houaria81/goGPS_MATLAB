%   CLASS Command Interpreter
% =========================================================================
%
% DESCRIPTION
%   Interpreter of goGPS command instructions
%
% EXAMPLE
%   cmd = Command_Interpreter.getInstance();
%
% FOR A LIST OF CONSTANTs and METHODS use doc Command_Interpreter


%--------------------------------------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __|
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 0.6.0 alpha 4 - nightly
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2018 Mirko Reguzzoni, Eugenio Realini
%  Written by:       Gatti Andrea
%  Contributors:     Gatti Andrea, ...
%  A list of all the historical goGPS contributors is in CREDITS.nfo
%--------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
% 01100111 01101111 01000111 01010000 01010011
%--------------------------------------------------------------------------

classdef Command_Interpreter < handle        
    %% PROPERTIES CONSTANTS
    % ==================================================================================================================================================
    properties (Constant, GetAccess = private)
        OK       = 0;    % No errors
        ERR_UNK  = 1;    % Command unknown
        ERR_NEI  = 2;    % Not Enough Input Parameters
        WRN_TMI  = -3;   % Too Many Inputs
        WRN_MPT  = -100; % Command empty
        
        STR_ERR = {'Commad unknown', ...
            'Not enough input parameters', ...
            'Too many input parameters'};
    end
    %
    %% PROPERTIES COMMAND CONSTANTS
    % ==================================================================================================================================================
    properties (GetAccess = public, SetAccess = private)
        % List of the supported commands
        
        CMD_LOAD        % Load data from the linked RINEX file into the receiver
        CMD_EMPTY       % Reset the receiver content
        CMD_AZEL        % Compute (or update) Azimuth and Elevation
        CMD_BASICPP     % Basic Point positioning with no correction (useful to compute azimuth and elevation)
        CMD_PREPRO      % Pre-processing command
        CMD_CODEPP      % Code point positioning
        CMD_PPP         % Precise point positioning
        CMD_NET         % Network undifferenced solution
        CMD_SEID        % SEID processing (synthesise L2)
        CMD_REMIONO     % SEID processing (reduce L*)
        CMD_KEEP        % Function to keep just some observations into receivers (e.g. rate => constellation)
        CMD_SYNC        % Syncronization among multiple receivers (same rate)
        CMD_OUTDET      % Outlier and cycle-slip detection
        CMD_SHOW        % Display plots and images
        CMD_EXPORT      % Export results
        
        KEY_FOR         % For each session keyword
        KEY_ENDFOR      % For marker end

        PAR_RATE        % Parameter select rate
        PAR_CUTOFF      % Parameter select cutoff
        PAR_SNRTHR      % Parameter select snrthr
        PAR_SS          % Parameter select constellation
        PAR_SYNC        % Parameter sync
        
        PAR_S_ALL       % show all plots
        PAR_S_DA        % Data availability
        PAR_S_ENU       % ENU positions
        PAR_S_ENUBSL    % Baseline ENU positions
        PAR_S_XYZ       % XYZ positions
        PAR_S_MAP       % positions on map
        PAR_S_CK        % Clock Error
        PAR_S_SNR       % SNR Signal to Noise Ratio
        PAR_S_OCS       % Outliers and cycle slips
        PAR_S_OCSP      % Outliers and cycle slips (polar plot)
        PAR_S_RES_SKY   % Residuals sky plot
        PAR_S_RES_SKYP  % Residuals sky plot (polar plot)
        PAR_S_ZTD       % ZTD
        PAR_S_PWV       % PWV
        PAR_S_STD       % ZTD Slant
        PAR_S_RES_STD   % Slant Total Delay Residuals (polar plot)
        PAR_E_TROPO_SNX % Tropo paramters sinex format
        PAR_E_TROPO_MAT % Tropo paramters mat format

        PAR_S_SAVE      % flage for saving
                
        KEY_LIST = {'FOR', 'ENDFOR'};
        CMD_LIST = {'LOAD', 'EMPTY', 'AZEL', 'BASICPP', 'PREPRO', 'CODEPP', 'PPP', 'NET', 'SEID', 'REMIONO', 'KEEP', 'SYNC', 'OUTDET', 'SHOW', 'EXPORT'};
        VALID_CMD = {};
        CMD_ID = [];
        KEY_ID = [];
        % Struct containing cells are not created properly as constant => see init method
    end
    %
    %% PROPERTIES SINGLETON POINTERS
    % ==================================================================================================================================================
    properties % Utility Pointers to Singletons
        log
        core
    end
    %
    %% METHOD CREATOR
    % ==================================================================================================================================================
    methods (Static, Access = public)
        % Concrete implementation.  See Singleton superclass.
        function this = Command_Interpreter(varargin)
            % Core object creator
            this.log = Logger.getInstance();
            this.init(varargin{1});
        end
    end
    %
    %% METHOD INTERFACE
    % ==================================================================================================================================================
    methods (Static, Access = public)
        function this = getInstance(varargin)
            % Get the persistent instance of the class
            persistent unique_instance_cmdi__
            unique_instance_cmdi__ = [];
            
            if isempty(unique_instance_cmdi__)
                this = Command_Interpreter(varargin);
                unique_instance_cmdi__ = this;
            else
                this = unique_instance_cmdi__;
                this.init(varargin);
            end
        end
    end
    %
    %% METHODS INIT
    % ==================================================================================================================================================
    methods
        function init(this, core)
            % Define and fill the "CONSTANT" structures of the class
            % Due to MATLAB limits it is not possible to create cells into struct on declaration
            %
            % SYNTAX:
            %   this.init()
            
            % definition of parameters (ToDo: these should be converted into objects)
            % in the definition the character "$" indicate the parameter value
            
            if nargin == 2
                if iscell(core) && ~isempty(core) && ~isempty(core{1})
                    core = core{1};
                end
                if ~isempty(core)
                    this.core = core;
                end
            end
            this.PAR_RATE.name = 'rate';
            this.PAR_RATE.descr = '@<rate>            processing rate in seconds (e.g. @30s, -r=30s)';
            this.PAR_RATE.par = '(\@)|(\-r\=)|(\-\-rate\=)'; % (regexp) parameter prefix: @ | -r= | --rate= 
            this.PAR_RATE.class = 'double';
            this.PAR_RATE.limits = [0.000001 900];
            this.PAR_RATE.accepted_values = [];
            
            this.PAR_CUTOFF.name = 'cut-off';
            this.PAR_CUTOFF.descr = '-e=<elevation>     elevation in degree (e.g. -e=7)';
            this.PAR_CUTOFF.par = '(\-e\=)|(\-\-cutoff\=)'; % (regexp) parameter prefix: @ | -e= | --cutoff= 
            this.PAR_CUTOFF.class = 'double';
            this.PAR_CUTOFF.limits = [0 90];
            this.PAR_CUTOFF.accepted_values = [];

            this.PAR_SNRTHR.name = 'SNR threshold';
            this.PAR_SNRTHR.descr = '-q=<snrthr>        SNR threshold in dbHZ on L1 (e.g. -q=7)';
            this.PAR_SNRTHR.par = '(\-q\=)|(\-\-snrthr\=)'; % (regexp) parameter prefix: @ | -q= | --snrthr= 
            this.PAR_SNRTHR.class = 'double';
            this.PAR_SNRTHR.limits = [0 70];
            this.PAR_SNRTHR.accepted_values = [];

            this.PAR_SS.name = 'constellation';
            this.PAR_SS.descr = '-s=<sat_list>      active constellations (e.g. -s=GRE)';
            this.PAR_SS.par = '(\-s\=)|(\-\-constellation\=)'; % (regexp) parameter prefix: -s --constellation
            this.PAR_SS.class = 'char';
            this.PAR_SS.limits = [];
            this.PAR_SS.accepted_values = [];
            
            this.PAR_SYNC.name = 'sync results';
            this.PAR_SYNC.descr = '--sync             use syncronized time only';
            this.PAR_SYNC.par = '(\-\-sync)';
            this.PAR_SYNC.class = '';
            this.PAR_SYNC.limits = [];
            this.PAR_SYNC.accepted_values = [];
            
            % Show plots
            this.PAR_S_ALL.name = 'Show all the plots';
            this.PAR_S_ALL.descr = 'SHOWALL';
            this.PAR_S_ALL.par = '(ALL)|(all)';

            this.PAR_S_DA.name = 'Data availability';
            this.PAR_S_DA.descr = 'DA               Data Availability';
            this.PAR_S_DA.par = '(DA)|(\-\-dataAvailability)|(da)';

            this.PAR_S_ENU.name = 'ENU positions';
            this.PAR_S_ENU.descr = 'ENU              East Nord Up positions';
            this.PAR_S_ENU.par = '(ENU)|(enu)';

            this.PAR_S_ENUBSL.name = 'ENU baseline';
            this.PAR_S_ENUBSL.descr = 'ENU              East Nord Up baseline';
            this.PAR_S_ENUBSL.par = '(ENUBSL)|(enu_base)';

            this.PAR_S_XYZ.name = 'XYZ positions';
            this.PAR_S_XYZ.descr = 'XYZ              XYZ Earth Fixed Earth centered positions';
            this.PAR_S_XYZ.par = '(XYZ)|(xyz)';

            this.PAR_S_MAP.name = 'Position on map';
            this.PAR_S_MAP.descr = 'MAP              Position on map';
            this.PAR_S_MAP.par = '(MAP)|(map)';

            this.PAR_S_CK.name = 'Clock Error';
            this.PAR_S_CK.descr = 'CK               Clock errors';
            this.PAR_S_CK.par = '(ck)|(CK)';

            this.PAR_S_SNR.name = 'SNR Signal to Noise Ratio';
            this.PAR_S_SNR.descr = 'SNR              Signal to Noise Ratio (polar plot)';
            this.PAR_S_SNR.par = '(snr)|(SNR)';
            
            this.PAR_S_OCS.name = 'Outliers and cycle slips';
            this.PAR_S_OCS.descr = 'OCS              Outliers and cycle slips';
            this.PAR_S_OCS.par = '(ocs)|(OCS)';
            
            this.PAR_S_OCSP.name = 'Outliers and cycle slips (polar plot)';
            this.PAR_S_OCSP.descr = 'OCSP             Outliers and cycle slips (polar plot)';
            this.PAR_S_OCSP.par = '(ocsp)|(OCSP)';
            
            this.PAR_S_RES_SKY.name = 'Residuals sky plot';
            this.PAR_S_RES_SKY.descr = 'RES_SKY          Residual sky plot';
            this.PAR_S_RES_SKY.par = '(res_sky)|(RES_SKY)';

            this.PAR_S_RES_SKYP.name = 'Residuals sky plot (polar plot)';
            this.PAR_S_RES_SKYP.descr = 'RES_SKYP         Residual sky plot (polar plot)';
            this.PAR_S_RES_SKYP.par = '(res_skyp)|(RES_SKYP)';

            this.PAR_S_ZTD.name = 'ZTD';
            this.PAR_S_ZTD.descr = 'ZTD              Zenithal Total Delay';
            this.PAR_S_ZTD.par = '(ztd)|(ZTD)';

            this.PAR_S_PWV.name = 'PWV';
            this.PAR_S_PWV.descr = 'PWV              Precipitable Water Vapour';
            this.PAR_S_PWV.par = '(pwv)|(PWV)';

            this.PAR_S_STD.name = 'ZTD Slant';
            this.PAR_S_STD.descr = 'STD              Zenithal Total Delay with slants';
            this.PAR_S_STD.par = '(std)|(STD)';

            this.PAR_S_RES_STD.name = 'Slant Total Delay Residuals (polar plot)';
            this.PAR_S_RES_STD.descr = 'RES_STD          Slants Total Delay residuals (polar plot)';
            this.PAR_S_RES_STD.par = '(res_std)|(RES_STD)';

            this.PAR_E_TROPO_SNX.name = 'TROPO Sinex';
            this.PAR_E_TROPO_SNX.descr = 'TRP_SNX          Tropo parameters SINEX file';
            this.PAR_E_TROPO_SNX.par = '(trp_snx)|(TRP_SNX)';

            this.PAR_E_TROPO_MAT.name = 'TROPO Matlab format';
            this.PAR_E_TROPO_MAT.descr = 'TRP_MAT          Tropo parameters matlab .mat file';
            this.PAR_E_TROPO_MAT.par = '(trp_mat)|(TRP_MAT)';
            
            % definition of commands
            
            new_line = [char(10) '             ']; %#ok<CHARTEN>
            this.CMD_LOAD.name = {'LOAD', 'load'};
            this.CMD_LOAD.descr = 'Import the RINEX file linked with this receiver';
            this.CMD_LOAD.rec = 'T';
            this.CMD_LOAD.par = [this.PAR_SS, this.PAR_RATE];

            this.CMD_EMPTY.name = {'EMPTY', 'empty'};
            this.CMD_EMPTY.descr = 'Empty the receiver';
            this.CMD_EMPTY.rec = 'T';
            this.CMD_EMPTY.par = [];

            this.CMD_AZEL.name = {'AZEL', 'UPDATE_AZEL', 'update_azel', 'azel'};
            this.CMD_AZEL.descr = 'Compute Azimuth and elevation ';
            this.CMD_AZEL.rec = 'T';
            this.CMD_AZEL.par = [];

            this.CMD_BASICPP.name = {'BASICPP', 'PP', 'basic_pp', 'pp'};
            this.CMD_BASICPP.descr = 'Basic Point positioning with no correction';
            this.CMD_BASICPP.rec = 'T';
            this.CMD_BASICPP.par = [this.PAR_RATE this.PAR_SS];

            this.CMD_PREPRO.name = {'PREPRO', 'pre_processing'};
            this.CMD_PREPRO.descr = ['Code positioning, computation of satellite positions and various' new_line 'corrections'];
            this.CMD_PREPRO.rec = 'T';
            this.CMD_PREPRO.par = [this.PAR_RATE this.PAR_SS];
            
            this.CMD_CODEPP.name = {'CODEPP', 'ls_code_point_positioning'};
            this.CMD_CODEPP.descr = 'Code positioning';
            this.CMD_CODEPP.rec = 'T';
            this.CMD_CODEPP.par = [this.PAR_RATE this.PAR_SS];
            
            this.CMD_PPP.name = {'PPP', 'precise_point_positioning'};
            this.CMD_PPP.descr = 'Precise Point Positioning using carrier phase observations';
            this.CMD_PPP.rec = 'T';
            this.CMD_PPP.par = [this.PAR_RATE this.PAR_SS this.PAR_SYNC];
            
            this.CMD_NET.name = {'NET', 'network'};
            this.CMD_NET.descr = 'Network solution using undifferenced carrier phase observations';
            this.CMD_NET.rec = 'TR';
            this.CMD_NET.par = [this.PAR_RATE this.PAR_SS this.PAR_SYNC];
            
            this.CMD_SEID.name = {'SEID', 'synthesise_L2'};
            this.CMD_SEID.descr = ['Generate a Synthesised L2 on a target receiver ' new_line 'using n (dual frequencies) reference stations'];
            this.CMD_SEID.rec = 'RT';
            this.CMD_SEID.par = [];
            
            this.CMD_REMIONO.name = {'REMIONO', 'remove_iono'};
            this.CMD_REMIONO.descr = ['Remove ionosphere from observations on a target receiver ' new_line 'using n (dual frequencies) reference stations'];
            this.CMD_REMIONO.rec = 'RT';
            this.CMD_REMIONO.par = [];
            
            this.CMD_KEEP.name = {'KEEP'};
            this.CMD_KEEP.descr = ['Keep in the object the data of a certain constallation' new_line 'at a certain rate'];
            this.CMD_KEEP.rec = 'T';
            this.CMD_KEEP.par = [this.PAR_RATE this.PAR_SS this.PAR_CUTOFF this.PAR_SNRTHR];
            
            this.CMD_SYNC.name = {'SYNC'};
            this.CMD_SYNC.descr = ['Syncronize all the receivers at the same rate ' new_line '(with the minimal data span)'];
            this.CMD_SYNC.rec = 'T';
            this.CMD_SYNC.par = [this.PAR_RATE];
            
            this.CMD_OUTDET.name = {'OUTDET', 'outlier_detection', 'cycle_slip_detection'};
            this.CMD_OUTDET.descr = 'Force outlier and cycle slip detection';
            this.CMD_OUTDET.rec = 'T';
            this.CMD_OUTDET.par = [];

            this.CMD_SHOW.name = {'SHOW'};
            this.CMD_SHOW.descr = 'Display various plots / images';
            this.CMD_SHOW.rec = 'T';
            this.CMD_SHOW.par = [this.PAR_S_DA this.PAR_S_ENU this.PAR_S_ENUBSL this.PAR_S_XYZ this.PAR_S_CK this.PAR_S_SNR this.PAR_S_OCS this.PAR_S_OCSP this.PAR_S_RES_SKY this.PAR_S_RES_SKYP this.PAR_S_ZTD this.PAR_S_PWV this.PAR_S_STD this.PAR_S_RES_STD];

            this.CMD_EXPORT.name = {'EXPORT', 'export_results', 'export_results'};
            this.CMD_EXPORT.descr = 'Export results';
            this.CMD_EXPORT.rec = 'T';
            this.CMD_EXPORT.par = [this.PAR_E_TROPO_SNX this.PAR_E_TROPO_MAT];

            this.KEY_FOR.name = {'FOR', 'for'};
            this.KEY_FOR.descr = 'For session loop start';
            this.KEY_FOR.rec = '';
            this.KEY_FOR.sss = 'S';
            this.KEY_FOR.par = [];

            this.KEY_ENDFOR.name = {'ENDFOR', 'END_FOR', 'end_for'};
            this.KEY_ENDFOR.descr = 'For loop end';
            this.KEY_ENDFOR.rec = '';
            this.KEY_ENDFOR.sss = '';
            this.KEY_ENDFOR.par = [];

            % When adding a command remember to add it to the valid_cmd list
            % Create the launcher exec function
            % and modify the method exec to allow execution
            this.VALID_CMD = {};
            this.CMD_ID = [];
            this.KEY_ID = [];
            for c = 1 : numel(this.CMD_LIST)
                this.VALID_CMD = [this.VALID_CMD(:); this.(sprintf('CMD_%s', this.CMD_LIST{c})).name(:)];
                this.CMD_ID = [this.CMD_ID, c * ones(size(this.(sprintf('CMD_%s', this.CMD_LIST{c})).name))];
                this.(sprintf('CMD_%s', this.CMD_LIST{c})).id = c;
            end
            for c = 1 : numel(this.KEY_LIST)
                this.VALID_CMD = [this.VALID_CMD(:); this.(sprintf('KEY_%s', this.KEY_LIST{c})).name(:)];
                this.CMD_ID = [this.CMD_ID, (c + numel(this.CMD_LIST)) * ones(size(this.(sprintf('KEY_%s', this.KEY_LIST{c})).name))];
                this.KEY_ID = [this.KEY_ID, (c + numel(this.CMD_LIST)) * ones(size(this.(sprintf('KEY_%s', this.KEY_LIST{c})).name))];
                this.(sprintf('KEY_%s', this.KEY_LIST{c})).id = (c + numel(this.CMD_LIST));
            end            
        end
        
        function str = getHelp(this)
            % Get a string containing the "help" description to all the supported commands
            %
            % SYNTAX:
            %   str = this.getHelp()
            str = sprintf('Accepted commands:\n');
            str = sprintf('%s--------------------------------------------------------------------------------\n', str);
            for c = 1 : numel(this.CMD_LIST)
                cmd_name = this.(sprintf('CMD_%s', this.CMD_LIST{c})).name{1};
                str = sprintf('%s - %s\n', str, cmd_name);
            end
            str = sprintf('%s\nCommands description:\n', str);
            str = sprintf('%s--------------------------------------------------------------------------------\n', str);
            for c = 1 : numel(this.CMD_LIST)
                cmd = this.(sprintf('CMD_%s', this.CMD_LIST{c}));
                str = sprintf('%s - %s%s%s\n', str, cmd.name{1}, ones(1, 10-numel(cmd.name{1})) * ' ', cmd.descr);
                if ~isempty(cmd.rec)
                    str = sprintf('%s\n%s%s', str, ones(1, 13) * ' ', 'Mandatory receivers:');
                    if numel(cmd.rec) > 1
                        rec_par = sprintf('%c%s', cmd.rec(1), sprintf(', %c', cmd.rec(2:end)));
                    else
                        rec_par = cmd.rec(1);
                    end
                    str = sprintf('%s %s\n', str, rec_par);
                end
                
                if ~isempty(cmd.par)
                    str = sprintf('%s\n%s%s\n', str, ones(1, 13) * ' ', 'Optional parameters:');
                    for p = 1 : numel(cmd.par)
                        str = sprintf('%s%s%s\n', str, ones(1, 15) * ' ', cmd.par(p).descr);
                    end
                end
                str = sprintf('%s\n--------------------------------------------------------------------------------\n', str);
            end
            for c = 1 : numel(this.KEY_LIST)
                cmd = this.(sprintf('KEY_%s', this.KEY_LIST{c}));
                str = sprintf('%s - %s%s%s\n', str, cmd.name{1}, ones(1, 10-numel(cmd.name{1})) * ' ', cmd.descr);
                if ~isempty(cmd.rec)
                    str = sprintf('%s\n%s%s', str, ones(1, 13) * ' ', 'Mandatory receivers:');
                    if numel(cmd.rec) > 1
                        rec_par = sprintf('%c%s', cmd.rec(1), sprintf(', %c', cmd.rec(2:end)));
                    else
                        rec_par = cmd.rec(1);
                    end
                    str = sprintf('%s %s\n', str, rec_par);
                end
                
                if ~isempty(cmd.sss)
                    str = sprintf('%s\n%s%s', str, ones(1, 13) * ' ', 'Mandatory session:');
                    if numel(cmd.sss) > 1
                        rec_par = sprintf('%c%s', cmd.sss(1), sprintf(', %c', cmd.sss(2:end)));
                    else
                        rec_par = cmd.sss(1);
                    end
                    str = sprintf('%s %s\n', str, rec_par);
                end
                
                if ~isempty(cmd.par)
                    str = sprintf('%s\n%s%s\n', str, ones(1, 13) * ' ', 'Optional parameters:');
                    for p = 1 : numel(cmd.par)
                        str = sprintf('%s%s%s\n', str, ones(1, 15) * ' ', cmd.par(p).descr);
                    end
                end
                str = sprintf('%s\n--------------------------------------------------------------------------------\n', str);
            end
            
            str = sprintf(['%s\n   Note: "T" refers to Target receiver' ...
                '\n         "R" refers to reference receiver' ...
                '\n         Receivers can be identified with their id (as defined in "obs_name")' ...
                '\n         It is possible to provide multiple receivers (e.g. T* or T1:4 or T1,3:5)\n' ...
                ], str);
            
        end
        
        function str = getExamples(this)
            % Get a string containing the "examples" of processing
            %
            % SYNTAX:
            %   str = this.getHelp()
            str = sprintf(['# PPP processing', ...
                '\n# @5 seconds rate GPS GALILEO', ...
                '\n\n FOR S*' ...
                '\n    LOAD T* @5s -s=GE', ...
                '\n    PREPRO T*', ...
                '\n    PPP T*', ...
                '\n ENDFOR', ...
                '\n SHOW T* ZTD', ...
                '\n EXPORT T* TRP_SNX', ...
                '\n\n# Network undifferenced processing', ...
                '\n# @30 seconds rate GPS only', ...
                '\n# processing sessions from 5 to 10', ...
                '\n# using receivers 1,2 as reference\n# for the mean', ...                
                '\n\n FOR S5:10' ...
                '\n    LOAD T* @30s -s=G', ...
                '\n    PREPRO T*', ...
                '\n    PPP T1:2', ...
                '\n    NET T* R1,2', ...
                '\n ENDFOR', ...
                '\n SHOW T* MAP', ...
                '\n SHOW T* ENUBSL', ...
                '\n\n# PPP + SEID processing', ...
                '\n# 4 reference stations \n# + one L1 target', ...
                '\n# @30 seconds rate GPS', ...
                '\n\n FOR S*' ...
                '\n    LOAD T* @30s -s=G', ...
                '\n    PREPRO T*', ...
                '\n    PPP T1:4', ...
                '\n    SEID R1:4 T5', ...
                '\n    PPP R5', ...
                '\n ENDFOR', ...
                '\n SHOW T* ZTD']);
        end
    end
    %
    %% METHODS EXECUTE
    % ==================================================================================================================================================
    % methods to execute a set of goGPS Commands
    methods         
        function exec(this, rec, cmd_list, level)
            % run a set of commands (divided in cells of cmd_list)
            %
            % SYNTAX:
            %   this.exec(rec, cmd_list, level)
            if nargin < 3
                state = Global_Configuration.getCurrentSettings();
                cmd_list = state.getCommandList();
            end
            if ~iscell(cmd_list)
                cmd_list = {cmd_list};
            end            
            [cmd_list, ~, ~, ~, cmd_lev] = this.fastCheck(cmd_list);
            if nargin < 4 || isempty(level)
                level = cmd_lev;
            end

            
            % run each line
            for l = 1 : numel(cmd_list)
                tok = regexp(cmd_list{l},'[^ ]*', 'match'); % get command tokens
                this.log.newLine();
                this.log.addMarkedMessage(sprintf('Executing: %s', cmd_list{l}));
                this.log.starSeparator();
                
                switch upper(tok{1})
                    case this.CMD_LOAD.name                 % LOAD
                        this.runLoad(rec, tok(2:end));
                    case this.CMD_EMPTY.name                % EMPTY
                        this.runEmpty(rec, tok(2:end));
                    case this.CMD_AZEL.name                 % AZEL
                        this.runUpdateAzEl(rec, tok(2:end));
                    case this.CMD_BASICPP.name              % BASICPP
                        this.runBasicPP(rec, tok(2:end));
                    case this.CMD_PREPRO.name               % PREP
                        this.runPrePro(rec, tok(2:end));
                    case this.CMD_CODEPP.name               % CODEPP
                        this.runCodePP(rec, tok(2:end));
                    case this.CMD_PPP.name                  % PPP
                        this.runPPP(rec, tok(2:end));
                    case this.CMD_NET.name                  % NET
                        this.runNet(rec, tok(2:end));
                    case this.CMD_SEID.name                 % SEID
                        this.runSEID(rec, tok(2:end));
                    case this.CMD_REMIONO.name              % REMIONO
                        this.runRemIono(rec, tok(2:end));
                    case this.CMD_KEEP.name                 % KEEP
                        this.runKeep(rec.getWork(), tok(2:end));
                    case this.CMD_SYNC.name                 % SYNC
                        this.runSync(rec, tok(2:end));
                    case this.CMD_OUTDET.name               % OUTDET
                        this.runOutDet(rec, tok);
                    case this.CMD_SHOW.name                 % SHOW
                        this.runShow(rec, tok, level(l));
                    case this.CMD_EXPORT.name               % EXPORT
                        this.runExport(rec, tok, level(l));
                end
            end
        end
    end
    %
    %% METHODS EXECUTE (PRIVATE)
    % ==================================================================================================================================================
    % methods to execute a set of goGPS Commands
    methods (Access = public)    
        
        function runLoad(this, rec, tok)
            % Load the RINEX file into the object
            %
            % INPUT
            %   rec     list of rec objects
            %
            % SYNTAX
            %   this.load(rec)
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Importing data for receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    if sys_found
                        state = Global_Configuration.getCurrentSettings();
                        state.cc.setActive(sys_list);
                    end
                    [rate, found] = this.getNumericPar(tok, this.PAR_RATE.par);
                    if ~found
                        rate = []; % get the rate of the RINEX
                    end
                    if this.core.state.isRinexSession()
                        rec(r).importRinexLegacy(this.core.state.getRecPath(r, this.core.getCurSession()), rate);
                        rec(r).work.loaded_session = this.core.getCurSession();
                    else
                        [session_limits, out_limits] = this.core.state.getSessionLimits(this.core.getCurSession());
                        rec(r).importRinexes(this.core.rin_list(r).getCopy(), session_limits.first, session_limits.last, rate);
                        rec(r).work.loaded_session = this.core.getCurSession();
                        rec(r).work.setOutLimits(out_limits.first, out_limits.last);
                    end
                end
            end
        end
        
        function runEmpty(this, rec, tok)
            % Reset (empty) the receiver
            %
            % INPUT
            %   rec     list of rec objects
            %
            % SYNTAX
            %   this.empty(rec)
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Empty the receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    rec(r).reset();
                    rec(r).work.resetWorkSpace();
                end
            end
        end
        
        function runPrePro(this, rec, tok)
            % Execute Pre processing
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runPrePro(rec, tok)
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Pre-processing on receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    if rec(r).work.loaded_session ~=  this.core.getCurSession()
                        if sys_found
                            state = Global_Configuration.getCurrentSettings();
                            state.cc.setActive(sys_list);
                        end
                        if this.core.state.isRinexSession()
                            this.runLoad(rec, tok);
                        else
                            this.runLoad(rec, tok);
                        end
                    end
                    if sys_found
                        rec(r).work.preProcessing(sys_list);
                    else
                        rec(r).work.preProcessing();
                    end
                end
            end
        end
        
        function runUpdateAzEl(this, rec, tok)
            % Execute Computation of azimuth and elevation
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runUpdateAzEl(rec, tok)
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Computing azimuth and elevation for receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();                    
                    if rec(r).isEmpty
                        if sys_found
                            state = Global_Configuration.getCurrentSettings();
                            state.cc.setActive(sys_list);
                        end
                        rec(r).work.load();
                    end
                    rec(r).work.updateAzimuthElevation();
                    rec(r).work.pushResult();
                end
            end
        end
        
        function runBasicPP(this, rec, tok)
            % Execute Basic Point positioning with no correction (useful to compute azimuth and elevation)
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.basicPP(rec, tok)
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Computing basic position for receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    if rec(r).isEmpty
                        if sys_found
                            state = Global_Configuration.getCurrentSettings();
                            state.cc.setActive(sys_list);
                        end
                        rec(r).load();
                    end
                    if sys_found
                        rec(r).computeBasicPosition(sys_list);
                    else
                        rec(r).computeBasicPosition();
                    end
                end
            end
        end

        
        function runPPP(this, rec, tok)
            % Execute Precise Point Positioning
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runPPP(rec, tok)
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                for r = id_trg
                    if rec(r).work.isStatic
                        this.log.newLine();
                        this.log.addMarkedMessage(sprintf('StaticPPP on receiver %d: %s', r, rec(r).getMarkerName()));
                        this.log.smallSeparator();
                        this.log.newLine();
                        if sys_found
                            rec(r).work.staticPPP(sys_list);
                        else
                            rec(r).work.staticPPP();
                        end
                    else
                        this.log.addError('PPP for moving receiver not yet implemented :-(');
                    end
                end
            end
        end

        function runNet(this, rec, tok)
            % Execute Network undifferenced solution
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runPPP(rec, tok)
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                [id_ref, found_ref] = this.getMatchingRec(rec, tok, 'R');
                if ~found_ref
                    id_ref = id_trg; % Use all the receiver as mean reference
                end
                [~, id_ref] = intersect(id_trg, id_ref);
                net = Network(rec(id_trg));
                net.adjust(id_ref);       
            end
        end

        function runCodePP(this, rec, tok)
            % Execute Code Point Positioning
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runCodePP(rec, tok)            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                [sys_list, sys_found] = this.getConstellation(tok);
                [id_ref, found_ref] = this.getMatchingRec(rec, tok, 'R');
                for r = id_trg
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Code positioning on receiver %d: %s', id_trg, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    if sys_found
                        rec(r).initPositioning(sys_list);
                    else
                        rec(r).initPositioning();
                    end
                end
            end
        end
        
        function runSEID(this, rec, tok)
            % Synthesise L2 observations on a target receiver given a set of dual frequency reference stations
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runSEID(rec, tok)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found => nothing to do');
            else
                [id_ref, found_ref] = this.getMatchingRec(rec, tok, 'R');
                if ~found_ref
                    this.log.addWarning('No reference SEID station found -> nothing to do');
                else
                    tic; Core_SEID.getSyntL2(rec.getWork(id_ref), rec.getWork(id_trg)); toc;
                end
            end
        end
        
        function runRemIono(this, rec, tok)
            % Remove iono model from observations on a target receiver given a set of dual frequency reference stations
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runSEID(rec, tok)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found => nothing to do');
            else
                [id_ref, found_ref] = this.getMatchingRec(rec, tok, 'R');
                if ~found_ref
                    this.log.addWarning('No reference SEID station found -> nothing to do');
                else
                    tic; Core_SEID.remIono(rec.getWork(id_ref), rec.getWork(id_trg)); toc;
                end
            end
        end
        
        function runKeep(this, rec, tok)
            % Filter Receiver data
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runKeep(rec, tok)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                [rate, found] = this.getNumericPar(tok, this.PAR_RATE.par);
                if found
                    for r = id_trg
                        this.log.addMarkedMessage(sprintf('Keeping a rate of %ds for receiver %d: %s', rate, r, rec(r).parent.getMarkerName()));
                        if rec(r).isEmpty
                            rec(r).load();
                        end
                        rec(r).keep(rate);
                    end
                end
                [snr_thr, found] = this.getNumericPar(tok, this.PAR_SNRTHR.par);
                if found
                    for r = id_trg
                        % this.log.addMarkedMessage(sprintf('Keeping obs with SNR (L1) above %d dbHZ for receiver %d: %s', snr_thr, r, rec(r).getMarkerName()));
                        if rec(r).isEmpty
                            rec(r).load();
                        end
                        rec(r).remUnderSnrThr(snr_thr);
                    end
                end
                [cut_off, found] = this.getNumericPar(tok, this.PAR_CUTOFF.par);
                if found
                    for r = id_trg
                        % this.log.addMarkedMessage(sprintf('Keeping obs with elevation above %.1f for receiver %d: %s', cut_off, r, rec(r).getMarkerName()));
                        if rec(r).isEmpty
                            rec(r).load();
                        end
                        rec(r).remUnderCutOff(cut_off);
                    end
                end
                [sys_list, found] = this.getConstellation(tok);
                if found
                    for r = id_trg
                        this.log.addMarkedMessage(sprintf('Keeping constellations "%s" for receiver %d: %s', sys_list, r, rec(r).parent.getMarkerName()));
                        if rec(r).isEmpty
                            rec(r).load();
                        end
                        rec(r).keep([], sys_list);
                    end
                end
            end
        end
        
        function runOutDet(this, rec, tok)
            % Perform outlier rejection and cycle slip detection
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runOutDet(rec)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                for r = id_trg
                    this.log.addMarkedMessage(sprintf('Outlier rejection and cycle slip detection for receiver %d: %s', r, rec(r).getMarkerName()));
                    rec(r).updateRemoveOutlierMarkCycleSlip();
                end
            end
        end
        
        function runSync(this, rec, tok)
            % Filter Receiver data
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runKeep(rec, tok)
            [~, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                [rate, found] = this.getRate(tok);
                if found
                    Receiver.sync(rec, rate);
                else
                    Receiver.sync(rec);
                end
            end
        end
        
        function runShow(this, rec, tok, sss_lev)
            % Show Images
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runShow(rec, tok, level)
            if nargin < 3 || isempty(sss_lev)
                sss_lev = 0;
            end
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                for t = 1 : numel(tok) % gloabal for all target
                    try
                        if sss_lev == 0
                            trg = rec(id_trg);
                        else
                            trg = [rec(id_trg).work];
                        end
                        if ~isempty(regexp(tok{t}, ['^(' this.PAR_S_MAP.par ')*$'], 'once'))
                            trg.showMap();
                        elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_ZTD.par ')*$'], 'once'))
                            trg.showZtd();
                        elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_PWV.par ')*$'], 'once'))
                            trg.showPwv();
                        elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_STD.par ')*$'], 'once'))
                            trg.showZtdSlant();
                        elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_ENUBSL.par ')*$'], 'once'))
                            trg.showBaselineENU();
                        end
                        
                    catch ex
                        this.log.addError(sprintf('%s',ex.message));
                    end
                end
                
                for r = id_trg % different for each target
                    for t = 1 : numel(tok)
                        try
                            if sss_lev == 0
                                trg = rec(r);
                            else
                                trg = [rec(r).work];
                            end
                            
                            if ~isempty(regexp(tok{t}, ['^(' this.PAR_S_ALL.par ')*$'], 'once'))
                                trg.showAll();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_DA.par ')*$'], 'once'))
                                trg.showDataAvailability();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_ENU.par ')*$'], 'once'))
                                trg.showPositionENU();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_XYZ.par ')*$'], 'once'))
                                trg.showPositionXYZ();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_CK.par ')*$'], 'once'))
                                trg.showDt();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_SNR.par ')*$'], 'once'))
                                trg.showSNR_p();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_OCS.par ')*$'], 'once'))
                                trg.showOutliersAndCycleSlip();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_OCSP.par ')*$'], 'once'))
                                trg.showOutliersAndCycleSlip_p();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_RES_SKY.par ')*$'], 'once'))
                                trg.showResSky_c();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_RES_SKYP.par ')*$'], 'once'))
                                trg.showResSky_p();
                            elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_S_RES_STD.par ')*$'], 'once'))
                                trg.showZtdSlantRes_p();
                            end
                        catch ex
                            this.log.addError(sprintf('Receiver %s: %s', trg.getMarkerName, ex.message));
                        end
                    end
                end
            end
        end
        
        function runExport(this, rec, tok, sss_lev)
            % Export results
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runExport(rec, tok, level)
            if nargin < 3 || isempty(sss_lev)
                sss_lev = 0;
            end

            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                
                for r = id_trg % different for each target
                    this.log.newLine();
                    this.log.addMarkedMessage(sprintf('Exporting receiver %d: %s', r, rec(r).getMarkerName()));
                    this.log.smallSeparator();
                    this.log.newLine();
                    for t = 1 : numel(tok)
                        try
                            if sss_lev == 0 % run on all teh results (out)
                                if ~isempty(regexp(tok{t}, ['^(' this.PAR_E_TROPO_SNX.par ')*$'], 'once'))
                                    rec(r).out.exportTropoSINEX();
                                elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_E_TROPO_MAT.par ')*$'], 'once'))
                                    rec(r).out.exportTropoMat();
                                end
                            else % run in single session mode (work)
                                if ~isempty(regexp(tok{t}, ['^(' this.PAR_E_TROPO_SNX.par ')*$'], 'once'))
                                    rec(r).work.exportTropoSINEX();
                                elseif ~isempty(regexp(tok{t}, ['^(' this.PAR_E_TROPO_MAT.par ')*$'], 'once'))
                                    rec(r).work.exportTropoMat();
                                end
                            end
                        catch ex
                            this.log.addError(sprintf('Receiver %s: %s', rec(r).getMarkerName, ex.message));
                        end
                    end
                end
            end
        end

    end
    %
    %% METHODS UTILITIES (PRIVATE)
    % ==================================================================================================================================================
    methods (Access = public)       
        function [id_rec, found, matching_rec] = getMatchingRec(this, rec, tok, type) %#ok<INUSL>
            % Extract from a set of tokens the receivers to be used
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %   type    type of receavers to search for ('T'/'R'/'M') 
            %
            % SYNTAX
            %   [id_rec, found, matching_rec] = this.getMatchingRec(rec, tok, type)
            if nargin == 2
                type = 'T';
            end
            id_rec = [];
            found = false;
            matching_rec = [];
            t = 0;
            while ~found && t < numel(tok)
                t = t + 1;
                % Search receiver identified after the key character "type"
                if ~isempty(tok{t}) && tok{t}(1) == type
                    % Analyse all the receiver identified on the string
                    % e.g. T*        all the receivers
                    %      T1,3:5    receiver 1,3,4,5
                    str_rec = tok{t}(2:end);
                    take_all = ~isempty(regexp(str_rec,'[\*]*', 'once'));
                    if take_all
                        id_rec = 1 : numel(rec);
                    else
                        [ids, pos_ids] = regexp(str_rec,'[0-9]*', 'match');
                        ids = str2double(ids);
                        
                        % find *:*:*
                        [sequence, pos_sss] = regexp(str_rec,'[0-9]*:[0-9]*:[0-9]*', 'match');
                        
                        for s = 1 : numel(sequence)
                            pos_par = regexp(sequence{s},'[0-9]*');
                            id_before = find(pos_ids(:) == (pos_sss(s) + pos_par(1) - 1), 1, 'last');
                            %id_step = find(pos_ids(:) == (pos_sss(s) + pos_par(2) - 1), 1, 'first');                            
                            %id_after = find(pos_ids(:) == (pos_sss(s) + pos_par(3) - 1), 1, 'first');
                            id_step = id_before + 1; 
                            id_after = id_before + 2; 
                            if ~isempty(id_before)
                                id_sss = [id_sss ids(id_before) : ids(id_step) : ids(id_after)]; %#ok<AGROW>
                                ids(id_before : id_after) = [];
                                pos_ids(id_before : id_after) = [];
                            end                            
                        end
                        
                        pos_colon = regexp(str_rec,':*');
                        for p = 1 : numel(pos_colon)
                            id_before = find(pos_ids(:) < pos_colon(p), 1, 'last');
                            id_after = find(pos_ids(:) > pos_colon(p), 1, 'first');
                            if ~isempty(id_before) && ~isempty(id_after)
                                id_rec = [id_rec ids(id_before) : ids(id_after)]; %#ok<AGROW>
                            end
                        end
                        id_rec = unique([ids id_rec]);
                    end
                    found = ~isempty(id_rec);
                    if id_rec <= length(rec)
                        matching_rec = rec(id_rec);
                    else
                        matching_rec = [];
                    end
                end
            end            
        end
        
        function [id_sss, found] = getMatchingSession(this, tok) %#ok<INUSL>
            % Extract from a set of tokens the receivers to be used
            %
            % INPUT
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   [id_sss, found] = this.getMatchingSession(tok)            
            type = 'S';
            
            id_sss = [];
            found = false;
            t = 0;
            state = Global_Configuration.getCurrentSettings();
            while ~found && t < numel(tok)
                t = t + 1;
                % Search receiver identified after the key character "type"
                if ~isempty(tok{t}) && tok{t}(1) == type
                    % Analyse all the receiver identified on the string
                    % e.g. T*        all the receivers
                    %      T1,3:5    receiver 1,3,4,5
                    str_rec = tok{t}(2:end);
                    take_all = ~isempty(regexp(str_rec,'[\*]*', 'once'));
                    if take_all
                        id_sss = 1 : state.getSessionCount();
                    else
                        [ids, pos_ids] = regexp(str_rec,'[0-9]*', 'match');
                        ids = str2double(ids);
                        
                        % find *:*:*
                        [sequence, pos_sss] = regexp(str_rec,'[0-9]*:[0-9]*:[0-9]*', 'match');
                        
                        for s = 1 : numel(sequence)
                            pos_par = regexp(sequence{s},'[0-9]*');
                            id_before = find(pos_ids(:) == (pos_sss(s) + pos_par(1) - 1), 1, 'last');
                            %id_step = find(pos_ids(:) == (pos_sss(s) + pos_par(2) - 1), 1, 'first');                            
                            %id_after = find(pos_ids(:) == (pos_sss(s) + pos_par(3) - 1), 1, 'first');
                            id_step = id_before + 1; 
                            id_after = id_before + 2; 
                            if ~isempty(id_before)
                                id_sss = [id_sss ids(id_before) : ids(id_step) : ids(id_after)]; %#ok<AGROW>
                                ids(id_before : id_after) = [];
                                pos_ids(id_before : id_after) = [];
                            end                            
                        end
                        
                        % find *:*                                                
                        pos_colon = regexp(str_rec,':*');
                        for p = 1 : numel(pos_colon)
                            id_before = find(pos_ids(:) < pos_colon(p), 1, 'last');
                            id_after = find(pos_ids(:) > pos_colon(p), 1, 'first');
                            if ~isempty(id_before) && ~isempty(id_after)
                                id_sss = [id_sss ids(id_before) : ids(id_after)]; %#ok<AGROW>
                            end
                        end
                        id_sss = unique([ids id_sss]);
                        id_sss(id_sss > state.getSessionCount()) = [];
                    end
                    found = ~isempty(id_sss);
                end
            end
            if isempty(id_sss) % as default return all the sessions
                id_sss = 1 : state.getSessionCount();
            end

        end        
        
        function [num, found] = getNumericPar(this, tok, par_regexp)
            % Extract from a set of tokens a number for a certain parameter
            %
            % INPUT
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   [num, found] = this.getNumericPar(tok, this.PAR_RATE.par)
            found = false;            
            num = str2double(regexp([tok{:}], ['(?<=' par_regexp ')[+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)*'], 'match', 'once'));
            if ~isempty(num) && ~isnan(num)
                found = true;
            end
        end
        
        function [sys, found] = getConstellation(this, tok)
            % Extract from a set of tokens the constellation parameter
            %
            % INPUT
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   [sys, found] = this.getConstellation(tok)
            found = false;            
            sys = regexp([tok{:}], ['(?<=' this.PAR_SS.par ')[GREJCIS]*'], 'match', 'once');
            if ~isempty(sys)
                found = true;
            end
        end
        
        function [cmd, err, id] = getCommandValidity(this, str_cmd)
            % Extract from a string the goGPS command found
            %
            % INPUT
            %   str_cmd     command as a string
            %
            % OUTPUT
            %   cmd         command struct for the found command
            %   err         error number (==0 ok) (> 0 on error) (< 0 on warning)
            %    id         internal usage id in the VALID_CMD array
            %
            % SYNTAX
            %  [cmd, err, id] = getCommandValidity(this, str_cmd)
            err = 0;
            tok = regexp(str_cmd,'[^ ]*', 'match');
            cmd = [];
            id = [];
            if isempty(tok)
                err = this.WRN_MPT; % no command found
            else
                str_cmd = tok{1};
                id = this.CMD_ID((strcmp(str_cmd, this.VALID_CMD)));
                if isempty(id)
                    err = this.ERR_UNK; % command unknown
                else
                    if id > numel(this.CMD_LIST)
                        cmd = this.(sprintf('KEY_%s', this.KEY_LIST{id - numel(this.CMD_LIST)}));
                    else
                        cmd = this.(sprintf('CMD_%s', this.CMD_LIST{id}));
                    end
                    if ~isfield(cmd, 'sss')
                        cmd.sss = '';
                    end
                    if numel(tok) < (1 + numel(cmd.rec))
                        err = this.ERR_NEI; % not enough input parameters
                    elseif numel(tok) > (1 + numel(cmd.rec) + numel(cmd.par) + numel(cmd.sss))
                        err = this.WRN_TMI; % too many input parameters
                    end
                end
            end
        end
    end
    %
    %% METHODS UTILITIES
    % ==================================================================================================================================================
    methods
        function [cmd_list, err_list, execution_block, sss_list, sss_lev] = fastCheck(this, cmd_list)
            % Check a cmd list keeping the valid commands only
            %
            % INPUT
            %   cmd_list    command as a cell array
            %
            % OUTPUT
            %   cmd_list    list with all the valid commands
            %   err         error list
            %
            % SYNTAX
            %  [cmd, err_list, execution_block, sss_list, sss_lev] = fastCheck(this, cmd_list)
            if nargout > 3
                state = Global_Configuration.getCurrentSettings;
            end
            err_list = zeros(size(cmd_list));
            
            sss = 1;
            lev = 0;
            sss_id_counter = 0;
            execution_block = zeros(1, numel(cmd_list));
            sss_list = cell(numel(cmd_list), 1);
            sss_lev = zeros(1, numel(cmd_list));
            for c = 1 : numel(cmd_list)
                [cmd, err_list(c)] = this.getCommandValidity(cmd_list{c});
                if (nargout > 2)
                    if err_list(c) == 0 && (cmd.id == this.KEY_FOR.id)
                        % I need to loop
                        sss_id_counter = sss_id_counter + 1;
                        lev = lev + 1;
                        tok = regexp(cmd_list{c},'[^ ]*', 'match'); % get command tokens
                        sss = this.getMatchingSession(tok); % in the future use the session from a a command like FOR S1:0
                    end
                    if err_list(c) == 0 && (cmd.id == this.KEY_ENDFOR.id)
                        % I need to loop
                        sss_id_counter = sss_id_counter + 1;
                        lev = lev - 1;
                        sss = sss(end);
                    end
                end
                
                if err_list(c) > 0
                    this.log.addError(sprintf('%s - cmd %03d "%s"', this.STR_ERR{abs(err_list(c))}, c, cmd_list{c}));
                end
                if err_list(c) < 0 && err_list(c) > -100
                    this.log.addWarning(sprintf('%s - cmd %03d "%s"', this.STR_ERR{abs(err_list(c))}, c, cmd_list{c}));
                end
                execution_block(c) = sss_id_counter;
                sss_lev(c) = lev;
                sss_list{c} = sss;
            end            
            cmd_list = cmd_list(~err_list);
            execution_block = execution_block(~err_list);
            sss_list = sss_list(~err_list);
            sss_lev = sss_lev(~err_list);
            if nargout > 3 && sss_id_counter == 0 % no FOR found
                for s = 1 : numel(sss_list)
                    sss_list{s} = 1 : state.getSessionCount();
                end
            end
        end                
    end    
end
