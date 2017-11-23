%   CLASS Receiver
% =========================================================================
%
% DESCRIPTION
%   Class to store receiver data (observations, and characteristics
%
% EXAMPLE
%   trg = Receiver();
%
% FOR A LIST OF CONSTANTs and METHODS use doc Receiver

%--------------------------------------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 0.5.1 beta 3
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2017 Mirko Reguzzoni, Eugenio Realini
%  Written by:       Gatti Andrea
%  Contributors:     Gatti Andrea, Giulio Tagliaferro ...
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
%----------------------------------------------------------------------------------------------
classdef Receiver < handle
    
    properties (SetAccess = private, GetAccess = public)
        cc = Constellation_Collector('GRECJ'); % local cc
        w_bar                                  % handle to waitbar
        state                                  % local handle of state;
        logger                                 % handle to logger
    end
    
    properties (SetAccess = public, GetAccess = public)
        file           % file rinex object
        rin_type       % rinex version format
        
        ant            % antenna number
        ant_type       % antenna type
        ant_delta_h    % antenna height from the ground [m]
        ant_delta_en   % antenna east/north offset from the ground [m]
        
        name           % marker name
        type           % marker type
        rin_obs_code   % list of types per constellation
        ph_shift       %
        
        xyz;           % approximate position of the receiver (XYZ geocentric)
        dtR;           % reference clock error of the receiver [n_epochs x num_obs_code]
        dtR_obs_code   % clock error for each obs code {num_obs_code}
        rid            % receiver interobservation biases
        
        static         % static or dynamic receiver 1: static 0: dynamic
        
        n_sat = 0;     % number of satellites
        n_freq = 0;    % number of stored frequencies
        n_spe = [];    % number of observations per epoch
        
        time = [];     % internal time ref of the stored epochs
        rate;          % observations rate;
        dt = 0;        % clock offset of the receiver
        
        active_ids     % rows of active satellites
        wl             % wave-lenght of each row of row_id
        f_id           % frequency number e.g. L1 -> 1,  L2 ->2, E1 -> 1, E5b -> 3 ...
        ss_id          % satellite system number
        prn            % pseudo-range number of the satellite
        go_id          % internal id for a certain satellite
        system         % char id of the satellite system corresponding to the row_id
        
        obs_validity   % validity of the row (does it contains usable values?)
        
        obs_code       % obs code for each line of the data matrix obs
        obs            % huge obbservation matrix with all the observables for all the systems / frequencies / ecc ...
        
        clock_corrected_obs = false; % if the obs have been corrected with dt * v_light this flag should be true
        
        group_delay_status = 0;% flag to indicate if code measurement have been corrected using group delays (0: not corrected , 1: corrected)
        dts_delay_status   = 0;% flag to indicate if code and phase measurement have been corrected for the clock of the satellite(0: not corrected , 1: corrected)
        
        rec2sat = struct( ...
            'avail_index', [], ...    % boolean [n_epoch x n_sat] availability of satellites
            'err_tropo',   [], ...    % double  [n_epoch x n_sat] tropo error
            'err_iono',    [], ...    % double  [n_epoch x n_sat] iono error
            'solid_earth_corr', [],...% double  [n_epoch x n_sat] solid earth corrections
            'dtS',         [], ...    % double  [n_epoch x n_sat] staellite clok error at trasmission time
            'rel_clk_corr',[], ...    % double  [n_epoch x n_sat] relativistic correction at trasmission time
            'tot',         [], ...    % double  [n_epoch x n_sat] time of travel
            'az',          [], ...    % double  [n_epoch x n_sat] azimuth
            'el',          [], ...    % double  [n_epoch x n_sat] elevation
            'cs',          [], ...    % Core_Sky
            'XS_tx',       [] ...     % compute Satellite postion a t transmission time
            )
    end
    
    % ==================================================================================================================================================
    %  SETTER
    % ==================================================================================================================================================
    
    methods
        function this = Receiver(cc)
            % SYNTAX  this = Receiver(<cc>)
            this.initObs();
            this.logger = Logger.getInstance();
            this.state = Go_State.getCurrentSettings();
            if nargin == 1
                this.cc = cc;
            else
                this.cc = this.state.cc;
            end
            this.w_bar = Go_Wait_Bar.getInstance();
        end
        
        function initObs(this)
            % initialize the receiver obj
            this.file = [];             % file rinex object
            this.rin_type = 0;          % rinex version format
            
            this.ant          = 0;       % antenna number
            this.ant_type     = '';      % antenna type
            this.ant_delta_h  = 0;       % antenna height from the ground [m]
            this.ant_delta_en = [0 0];   % antenna east/north offset from the ground [m]
            
            this.name         = 'empty';  % marker name
            this.type         = '';       % marker type
            this.rin_obs_code = '';       % list of types per constellation
            this.ph_shift     = [];
            
            this.xyz          = [0 0 0];  % approximate position of the receiver (XYZ geocentric)
            
            this.n_sat = 0;               % number of satellites
            this.n_freq = 0;              % number of stored frequencies
            n_epo = 0;               % number of epochs stored
            this.n_spe = [];              % number of sat per epoch
            
            this.dt = 0;                  % clock offset of the receiver
            
            this.time = [];               % internal time ref of the stored epochs
            this.rate = 0;                % observations rate;
            
            this.active_ids = [];         % rows of active satellites
            this.wl         = [];         % wave-lenght of each row of row_id
            this.f_id       = [];         % frequency number e.g. L1 -> 1,  L2 ->2, E1 -> 1, E5b -> 3 ...
            this.ss_id      = [];         % satellite system number
            this.prn        = [];         % pseudo-range number of the satellite
            this.go_id      = [];         % internal id for a certain satellite
            this.system     = '';         % char id of the satellite system corresponding to the row_id
            
            this.obs_validity = [];       % validity of the row (does it contains usable values?)
            
            this.obs_code   = [];         % obs code for each line of the data matrix obs
            this.obs        = [];         % huge obbservation matrix with all the observables for all the systems / frequencies / ecc ...
            
            this.clock_corrected_obs = false; % if the obs have been corrected with dt * v_light this flag should be true
            
            this.initR2S();
        end
        
        function initR2S(this)
            % initialize satellite related parameters
            % SYNTAX: this.initR2S();
            
            this.rec2sat.cs                   = Core_Sky.getInstance();
            this.rec2sat.tot          = NaN(this.getNumEpochs, this.cc.getNumSat);
            %  this.rec2sat.XS_tx     = NaN(n_epoch, n_pr); % --> consider what to initialize
        end
        
        function loadRinex(this, file_name)
            % SYNTAX:
            %   this.loadRinex(file_name)
            %
            % INPUT:
            %   filename = RINEX observation file(s)
            %
            % OUTPUT:
            %   pr1 = code observation (L1 carrier)
            %   ph1 = phase observation (L1 carrier)
            %   pr2 = code observation (L2 carrier)
            %   ph2 = phase observation (L2 carrier)
            %   dop1 = Doppler observation (L1 carrier)
            %   dop2 = Doppler observation (L2 carrier)
            %   snr1 = signal-to-noise ratio (L1 carrier)
            %   snr2 = signal-to-noise ratio (L2 carrier)
            %   time = receiver seconds-of-week
            %   week = GPS week
            %   date = date (year,month,day,hour,minute,second)
            %   pos = rover approximate position
            %   interval = observation time interval [s]
            %   antoff = antenna offset [m]
            %   antmod = antenna model [string]
            %   codeC1 = boolean variable to notify if the C1 code is used instead of P1
            %   marker = marker name [string]
            %
            % DESCRIPTION:
            %   Parses RINEX observation files.
            
            t0 = tic;
            
            this.logger.addMarkedMessage('Reading observations...');
            this.logger.newLine();
            
            this.file =  File_Rinex(file_name, 9);
            
            if this.file.isValid()
                this.logger.addMessage(sprintf('Opening file %s for reading', file_name), 100);
                % open RINEX observation file
                fid = fopen(file_name,'r');
                txt = fread(fid,'*char')';
                fclose(fid);
                
                % get new line separators
                nl = regexp(txt, '\n')';
                if nl(end) <  numel(txt)
                    nl = [nl; numel(txt)];
                end
                lim = [[1; nl(1 : end - 1) + 1] (nl - 1)];
                lim = [lim lim(:,2) - lim(:,1)];
                if lim(end,3) < 3
                    lim(end,:) = [];
                end
                
                % importing header informations
                eoh = this.file.eoh;
                this.parseRinHead(txt, lim, eoh);
                
                if (this.rin_type < 3)
                    % considering rinex 2
                    this.parseRin2Data(txt, lim, eoh);
                    
                    
                else
                    % considering rinex 3
                    this.parseRin3Data(txt, lim, eoh);
                end
                % guess rinex3 flag for incomplete flag (probably
                % comning from rinex2)
                % WARNING!! (C/A) + (P2-P1) semi codeless tracking (flag
                % C2D)
                % receiver not supporter (in rinex 2) convert them
                % using cc2noncc converter
                % https://github.com/ianmartin/cc2noncc (not tested)
                % GPS C1 -> C1C
                idx = this.getObsIdx('C1 ','G');
                this.obs_code(idx,:) = repmat('C1C',length(idx),1);
                % GPS C2 -> C2C
                idx = this.getObsIdx('C2 ','G');
                this.obs_code(idx,:) = repmat('C2C',length(idx),1);
                % GPS C5 -> C5I
                idx = this.getObsIdx('C5 ','G');
                this.obs_code(idx,:) = repmat('C5I',length(idx),1);
                % GPS P1 -> C1W
                idx = this.getObsIdx('P1 ','G');
                this.obs_code(idx,:) = repmat('C1W',length(idx),1);
                % GPS P2 -> C2W
                idx = this.getObsIdx('P2 ','G');
                this.obs_code(idx,:) = repmat('C2W',length(idx),1);
                % GLONASS C1 -> C1C
                idx = this.getObsIdx('C1 ','R');
                this.obs_code(idx,:) = repmat('C1C',length(idx),1);
                % GLONASS C2 -> C2C
                idx = this.getObsIdx('C2 ','R');
                this.obs_code(idx,:) = repmat('C2C',length(idx),1);
                % GLONASS P1 -> C1P
                idx = this.getObsIdx('P1 ','R');
                this.obs_code(idx,:) = repmat('C1P',length(idx),1);
                % GLONASS P2 -> C2P
                idx = this.getObsIdx('P2 ','R');
                this.obs_code(idx,:) = repmat('C2P',length(idx),1);
                % other flags to be investiagated
                
                this.logger.addMessage(sprintf('Parsing completed in %.2f seconds', toc(t0)));
                this.logger.newLine();
            end
            
            % Compute the other useful status array of the receiver object
            this.updateStatus();
            this.active_ids = true(this.getNumObservables, 1);
            
            % remove empty observables
            this.remObs(~this.obs_validity)
        end
        
        function updateStatus(this)
            % Compute the other useful status array of the receiver object
            % SYNTAX this.updateStatus();
            [~, this.ss_id] = ismember(this.system, this.cc.SYS_C);
            this.ss_id = this.ss_id';
            this.n_freq = numel(unique(this.f_id));
            
            this.go_id = this.prn + reshape(this.cc.n_sat(this.ss_id),length(this.prn),1); %%% some time second vector is a colum some time is a line reshape added to uniform
            this.n_sat = numel(unique(this.go_id));
            
            % Compute number of satellite per epoch
            
            % considerig only epoch with code on the first frequency
            code_line = this.obs_code(:,1) == 'C' & this.f_id == 1;
            this.n_spe = sum(this.obs(code_line, :) ~= 0);
            % more generic approach bbut a lot slower
            %for e = 1 : this.getNumEpochs()
            %    this.n_spe(e) = numel(unique(this.go_id(this.obs(:,e) ~= 0)));
            %end
            
            this.obs_validity = any(this.obs, 2);
            
            this.rec2sat.avail_index = false(this.time.length, this.cc.getNumSat());
        end
        
        function remEpoch(this, id_epo)
            % remove epochs with a certain id
            % SYNTAX:   this.remObs(id_obs)
            
            this.obs(:,epo) = [];
            this.time.delId(id_opo);
            if numel(this.dt) == this.getNumObservables()
                this.dt(id_epo) = [];
            end
            
            this.obs_validity = any(this.obs, 2);
        end
        
        function remObs(this, id_obs)
            % remove observations with a certain id
            % SYNTAX:   this.remObs(id_obs)
            
            this.obs(id_obs,:) = [];
            
            this.active_ids(id_obs) = [];
            this.obs_validity(id_obs) = [];
            
            this.wl(id_obs) = [];
            this.f_id(id_obs) = [];
            this.ss_id(id_obs) = [];
            this.prn(id_obs) = [];
            this.go_id(id_obs) = [];
            this.system(id_obs) = [];
            
            
            this.obs_code(id_obs, :) = [];

            
        end
        
        function applyDtDrift(this)
            % add dt * v_light to pseudo ranges and phases
            if ~this.clock_corrected_obs
                cpp = Core_Pre_Processing;
                d_dt = cpp.diffAndPred(this.dt);
                [d_dt] = simpleFill1D(d_dt, abs(d_dt) > 1e-4);
                dt = cumsum(d_dt);
                
                dt_corr = repmat(dt' * Go_State.V_LIGHT, size(this.ph, 1), 1);
                
                this.pr = this.pr - dt_corr;
                this.ph = this.ph - dt_corr;
                this.clock_corrected_obs = true;
            end
        end
        
        function remDtDrift(this)
            % del dt * v_light to pseudo ranges and phases
            if this.clock_corrected_obs
                cpp = Core_Pre_Processing;
                d_dt = cpp.diffAndPred(this.dt);
                [d_dt] = simpleFill1D(d_dt, abs(d_dt) > 1e-4);
                dt = cumsum(d_dt);
                
                dt_corr = repmat(dt * Go_State.V_LIGHT, 1, this.n_sat, this.n_freq);
                
                this.pr = this.pr + dt_corr;
                this.ph = this.ph + dt_corr;
                this.clock_corrected_obs = false;
            end
        end
        
        function parseRinHead(this, txt, lim, eoh)
            % Parse the header of the Observation Rinex file
            % SYNTAX:
            %    this.parseRinHead(txt, nl)
            % INPUT:
            %    txt    raw txt of the RINEX
            %    lim    indexes to determine start-stop of a line in "txt"  [n_line x 2/<3>]
            %    eoh    end of header line
            
            h_std{1} = 'RINEX VERSION / TYPE';                  %  1
            h_std{2} = 'PGM / RUN BY / DATE';                   %  2
            h_std{3} = 'MARKER NAME';                           %  3
            h_std{4} = 'OBSERVER / AGENCY';                     %  4
            h_std{5} = 'REC # / TYPE / VERS';                   %  5
            h_std{6} = 'ANT # / TYPE';                          %  6
            h_std{7} = 'APPROX POSITION XYZ';                   %  7
            h_std{8} = 'ANTENNA: DELTA H/E/N';                  %  8
            h_std{9} = 'TIME OF FIRST OBS';                     %  9
            
            h_opt{1} = 'MARKER NUMBER';                         % 10
            h_opt{2} = 'INTERVAL';                              % 11
            h_opt{3} = 'TIME OF LAST OBS';                      % 12
            h_opt{4} = 'LEAP SECONDS';                          % 13
            h_opt{5} = '# OF SATELLITES';                       % 14
            h_opt{6} = 'PRN / # OF OBS';                        % 15
            
            h_rin2_only{1} = '# / TYPES OF OBSERV';             % 16
            h_rin2_only{2} = 'WAVELENGTH FACT L1/2';            % 17
            
            h_rin3_only{1} = 'MARKER TYPE';                     % 18
            h_rin3_only{2} = 'SYS / # / OBS TYPES';             % 19
            h_rin3_only{3} = 'SYS / PHASE SHIFT';               % 20
            h_rin3_only{4} = 'GLONASS SLOT / FRQ #';            % 21
            h_rin3_only{5} = 'GLONASS COD/PHS/BIS';             % 22
            
            h_opt_rin3_only{1} = 'ANTENNA: DELTA X/Y/Z';        % 23
            h_opt_rin3_only{2} = 'ANTENNA:PHASECENTER';         % 24
            h_opt_rin3_only{3} = 'ANTENNA: B.SIGHT XYZ';        % 25
            h_opt_rin3_only{4} = 'ANTENNA: ZERODIR AZI';        % 26
            h_opt_rin3_only{5} = 'ANTENNA: ZERODIR XYZ';        % 27
            h_opt_rin3_only{6} = 'CENTER OF MASS: XYZ';         % 28
            h_opt_rin3_only{7} = 'SIGNAL STRENGTH UNIT';        % 29
            h_opt_rin3_only{8} = 'RCV CLOCK OFFS APPL';         % 30
            h_opt_rin3_only{9} = 'SYS / DCBS APPLIED';          % 31
            h_opt_rin3_only{10} = 'SYS / PCVS APPLIED';         % 32
            h_opt_rin3_only{11} = 'SYS / SCALE FACTOR';         % 33
            
            head_field = {h_std{:} h_opt{:} h_rin2_only{:} h_rin3_only{:} h_opt_rin3_only{:}}';
            
            % read RINEX type 3 or 2 ---------------------------------------------------------------------------------------------------------------------------
            l = 0;
            type_found = false;
            while ~type_found && l < eoh
                l = l + 1;
                if strcmp(strtrim(txt((lim(l,1) + 60) : lim(l,2))), h_std{1})
                    type_found = true;
                    dataset = textscan(txt(lim(1,1):lim(1,2)), '%f%c%18c%c');
                end
            end
            this.rin_type = dataset{1};
            if dataset{2} == 'O'
                if (this.rin_type < 3)
                    if (dataset{4} ~= 'G')
                        % GPS only RINEX2 - mixed or glonass -> actually not working
                        %throw(MException('VerifyInput:InvalidObservationFile', 'RINEX2 is supported for GPS only dataset, please use a RINEX3 file '));
                    else
                        % GPS only RINEX2 -> ok
                    end
                else
                    % RINEX 3 file -> ok
                end
            else
                throw(MException('VerifyInput:InvalidObservationFile', 'This observation RINEX does not contain observations'));
            end
            
            % parsing ------------------------------------------------------------------------------------------------------------------------------------------
            
            % retriving the kind of header information is contained on each line
            line2head = zeros(eoh, 1);
            l = 0;
            while l < eoh
                l = l + 1;
                %DEBUG: txt((lim(l,1) + 60) : lim(l,2))
                tmp = find(strcmp(strtrim(txt((lim(l,1) + 60) : lim(l,2))), head_field));
                if ~isempty(tmp)
                    % if the field have been recognized (it's not a comment)
                    line2head(l) = tmp;
                end
            end
            
            % reading parameters -------------------------------------------------------------------------------------------------------------------------------
            
            % 1) 'RINEX VERSION / TYPE'
            % already parsed
            % 2) 'PGM / RUN BY / DATE'
            % ignoring
            % 3) 'MARKER NAME'
            fln = find(line2head == 3, 1, 'first'); % get field line
            if isempty(fln)
                this.name = 'NO_NAME';
            else
                this.name = strtrim(txt(lim(fln, 1) + (0:59)));
            end
            % 4) 'OBSERVER / AGENCY'
            % ignoring
            % 5) 'REC # / TYPE / VERS'
            % ignoring
            % 6) 'ANT # / TYPE'
            fln = find(line2head == 6, 1, 'first'); % get field line
            if isempty(fln)
                this.ant = '';
                this.ant_type = '';
            else
                this.ant = strtrim(txt(lim(fln, 1) + (0:20)));
                this.ant_type = strtrim(txt(lim(fln, 1) + (21:40)));
            end
            % 7) 'APPROX POSITION XYZ'
            fln = find(line2head == 7, 1, 'first'); % get field line
            if isempty(fln)
                this.xyz = [0 0 0];
            else
                tmp = sscanf(txt(lim(fln, 1) + (0:41)),'%f')';                                               % read value
                this.xyz = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 3), [0 0 0], tmp);          % check value integrity
            end
            % 8) 'ANTENNA: DELTA H/E/N'
            fln = find(line2head == 8, 1, 'first'); % get field line
            if isempty(fln)
                this.ant_delta_h = 0;
                this.ant_delta_en = [0 0];
            else
                tmp = sscanf(txt(lim(fln, 1) + (0:13)),'%f')';                                                % read value
                this.ant_delta_h = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 1), 0, tmp);         % check value integrity
                tmp = sscanf(txt(lim(fln, 1) + (14:41)),'%f')';                                               % read value
                this.ant_delta_en = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 2), [0 0], tmp);    % check value integrity
            end
            % 9) 'TIME OF FIRST OBS'
            % ignoring it's already in this.file.first_epoch, but the code to read it is the following
            %fln = find(line2head == 9, 1, 'first'); % get field line
            %tmp = sscanf(txt(lim(fln, 1) + (0:42)),'%f')';
            %first_epoch = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 6), this.file.first_epoch, GPS_Time(tmp));    % check value integrity
            %first_epoch.setGPS(~strcmp(txt(lim(fln, 1) + (48:50)),'GLO'));
            % 10) 'MARKER NUMBER'
            % ignoring
            % 11) INTERVAL
            fln = find(line2head == 11, 1, 'first'); % get field line
            if isempty(fln)
                this.rate = 0; % If it's zero it'll be necessary to compute it
            else
                tmp = sscanf(txt(lim(fln, 1) + (0:9)),'%f')';                                  % read value
                this.rate = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 1), 0, tmp);  % check value integrity
            end
            % 12) TIME OF LAST OBS
            % ignoring it's already in this.file.last_epoch, but the code to read it is the following
            % fln = find(line2head == 12, 1, 'first'); % get field line
            % tmp = sscanf(txt(lim(fln, 1) + (0:42)),'%f')';
            % last_epoch = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 6), this.file.first_epoch, GPS_Time(tmp));    % check value integrity
            % last_epoch.setGPS(~strcmp(txt(lim(fln, 1) + (48:50)),'GLO'));
            % 13) LEAP SECONDS
            % ignoring
            % 14) # OF SATELLITES
            fln = find(line2head == 14, 1, 'first'); % get field line
            if isempty(fln)
                this.n_sat = this.cc.getNumSat(); % If it's zero it'll be necessary to compute it
            else
                tmp = sscanf(txt(lim(fln, 1) + (0:5)),'%f')';                                  % read value
                this.n_sat = iif(isempty(tmp) || ~isnumeric(tmp) || (numel(tmp) ~= 1), this.cc.getNumSat(), tmp);  % check value integrity
            end
            % 15) PRN / # OF OBS            % ignoring
            % 16) # / TYPES OF OBSERV
            if this.rin_type < 3
                fln = find(line2head == 16); % get field line
                rin_obs_code = [];
                if ~isempty(fln)
                    n_obs = sscanf(txt(lim(fln(1), 1) + (3:5)),'%d');
                    l = 1;
                    while l <= numel(fln)
                        n_line = ceil(n_obs / 9);
                        l_offset = 0;
                        while l_offset < n_line
                            rin_obs_code = [rin_obs_code sscanf(txt(lim(fln(l + l_offset), 1) + (6:59)),'%s')];
                            l_offset = l_offset + 1;
                        end
                        l = l + l_offset;
                    end
                    rin_obs_code = serialize([reshape(rin_obs_code, 2, numel(rin_obs_code) / 2); ' ' * ones(1, numel(rin_obs_code) / 2)])';
                end
                this.rin_obs_code = struct('g', rin_obs_code, 'r', rin_obs_code, 'e', rin_obs_code, 'j', rin_obs_code, 'c', rin_obs_code, 'i', rin_obs_code, 's', rin_obs_code);
                
            end
            % 17) WAVELENGTH FACT L1/2
            % ignoring
            % 18) MARKER TYPE
            % Assuming non geodetic type as default
            this.type = 'NON-GEODETIC';
            fln = find(line2head == 18, 1, 'first'); % get field line
            if ~isempty(fln)
                this.type = strtrim(txt(lim(fln, 1) + (0:19)));
            end
            
            % 19) SYS / # / OBS TYPES
            if this.rin_type >= 3
                fln = find(line2head == 19); % get field lines
                this.rin_obs_code = struct('g',[],'r',[],'e',[],'j',[],'c',[],'i',[],'s',[]);
                if ~isempty(fln)
                    l = 1;
                    while l <= numel(fln)
                        sys = char(txt(lim(fln(l), 1))+32);
                        n_obs = sscanf(txt(lim(fln(l), 1) + (3:5)),'%d');
                        n_line = ceil(n_obs / 13);
                        l_offset = 0;
                        while l_offset < n_line
                            obs_code_text = txt(lim(fln(l + l_offset), 1) + (7:59));
                            idx_code = true(length(obs_code_text),1);
                            idx_code(4:4:(floor(length(obs_code_text)/4)*4)) = false; % inedx to take only valid columns
                            obs_code_temp = obs_code_text(idx_code');
                            obs_code_temp((ceil(max(find(obs_code_temp ~= ' '))/3)*3 +1 ):end) = []; %delete empty lines at the end
                            this.rin_obs_code.(sys) = [this.rin_obs_code.(sys) obs_code_temp];
                            
                            l_offset = l_offset + 1;
                        end
                        l = l + l_offset;
                    end
                end
                if ~isempty(strfind(this.rin_obs_code.c, '1'))
                    this.rin_obs_code.c(this.rin_obs_code.c == '1') = '2';
                    this.logger.addWarning('BeiDou band 1 is now defined as 2 -> Automatically converting the observation codes of the RINEX!');
                end
            end
            % 20) SYS / PHASE SHIFT
            fln = find(line2head == 20); % get field line
            if this.rin_type < 3
                this.ph_shift = struct('g', zeros(numel(this.rin_obs_code.g) / 3, 1));
            else
                this.ph_shift = struct('g',[],'r',[],'e',[],'j',[],'c',[],'i',[],'s',[]);
                for l = 1 : numel(fln)
                    if txt(lim(fln(l), 1)) ~= ' ' % ignoring phase shif only on subset of satellites
                        sys = char(txt(lim(fln(l), 1)) + 32);
                        
                        rin_obs_code = txt(lim(fln(l), 1) + (2:4));
                        obs_id = (strfind(this.rin_obs_code.(sys), rin_obs_code) - 1) / 3 + 1;
                        if isempty(this.ph_shift.(sys))
                            this.ph_shift.(sys) = zeros(numel(this.rin_obs_code.(sys)) / 3, 1);
                        end
                        shift = sscanf(txt(lim(fln(l), 1) + (6:14)),'%f');
                        if ~isempty(shift)
                            this.ph_shift.(sys)(obs_id) = shift;
                        end
                    end
                end
            end
            % 21) GLONASS SLOT / FRQ #
            % ignoring
            % 22) GLONASS COD/PHS/BIS
            % ignoring
            % 23) ANTENNA: DELTA X/Y/Z
            % ignoring
            % 24) ANTENNA:PHASECENTER
            % ignoring
            % 25) ANTENNA: B.SIGHT XYZ
            % ignoring
            % 26) ANTENNA: ZERODIR AZI
            % ignoring
            % 27) ANTENNA: ZERODIR XYZ
            % ignoring
            % 28) CENTER OF MASS: XYZ
            % ignoring
            % 29) SIGNAL STRENGTH UNIT
            % ignoring
            % 30) RCV CLOCK OFFS APPL
            % ignoring
            % 31) SYS / DCBS APPLIED
            % ignoring
            % 32) SYS / PCVS APPLIED
            % ignoring
            % 33) SYS / SCALE FACTOR
            % ignoring
            
        end
        
        function chooseDataTypes(this)
            % get the right attribute column to be used for a certain type/band couple
            % LEGACY????
            t_ok = 'CLDS'; % type
            
            rin_obs_col = struct('g', zeros(4, numel(this.cc.gps.F_VEC)), ...
                'r', zeros(4, size(this.cc.glo.F_VEC,2)), ...
                'e', zeros(4, numel(this.cc.gal.F_VEC)), ...
                'j', zeros(4, numel(this.cc.qzs.F_VEC)), ...
                'c', zeros(4, numel(this.cc.bds.F_VEC)), ...
                'i', zeros(4, numel(this.cc.irn.F_VEC)), ...
                's', zeros(4, numel(this.cc.sbs.F_VEC)));
            
            if this.rin_type >= 3
                
                for c = 1 : numel(this.cc.SYS_C)
                    sys_c = char(this.cc.SYS_C(c) + 32);
                    sys = char(this.cc.SYS_NAME{c} + 32);
                    
                    if ~isempty(this.rin_obs_code.g)
                        code = reshape(this.rin_obs_code.(sys_c), 3, numel(this.rin_obs_code.(sys_c)) / 3)';
                        b_ok = this.cc.(sys).CODE_RIN3_2BAND;  % band
                        a_ok = this.cc.(sys).CODE_RIN3_ATTRIB; % attribute
                        for t = 1 : numel(t_ok)
                            for b = 1 : numel(b_ok)
                                % get the observation codes with a certain type t_ok(t) and band b_ok(b)
                                obs = (code(:,1) == t_ok(t)) & (code(:,2) == b_ok(b));
                                if any(obs)
                                    % find the preferred observation among the available ones
                                    [a, id] = intersect(code(obs, 3), a_ok{b}); a = a(id);
                                    % save the id of the column in the rin_obs_col struct matrix
                                    rin_obs_col.(sys_c)(t, b) = find(obs & code(:,3) == a(1));
                                end
                            end
                        end
                    end
                end
                
            else % rinex 2
                keyboard;
                % to be done
            end
        end
        
    end
    
    % ==================================================================================================================================================
    %  GETTER
    % ==================================================================================================================================================
    methods
        function n_obs = getNumObservables(this)
            % get the number of observables stored in the object
            % SYNTAX: n_obs = this.getNumObservables()
            n_obs = size(this.obs, 1);
        end
        
        function n_epo = getNumEpochs(this)
            % get the number of epochs stored in the object
            % SYNTAX: n_obs = this.getNumEpochs()
            n_epo = size(this.obs, 2);
        end
        
        function n_pr = getNumPseudoRanges(this)
            % get the number of epochs stored in the object
            % SYNTAX: n_pr = this.getNumPseudoRanges()
            n_pr = sum(rec.obs_code(:,1) == 'C');
        end
        
        function n_sat = getNumSat(this)
            % get the number of epochs stored in the object
            % SYNTAX: n_sat = this.getNumSat()
            n_sat = numel(unique(this.go_id));
        end
        
        function pr = pr1(this, flag_valid, sys_c)
            % get p_range 1 (Legacy)
            % SYNTAX this.pr1(<flag_valid>, <sys_c>)
            switch nargin
                case 1
                    id = (this.active_ids) & (this.f_id == 1);
                case 2
                    if flag_valid
                        id = (this.active_ids) & (this.f_id == 1) & this.pr_validity;
                    else
                        id = (this.active_ids) & (this.f_id == 1);
                    end
                case 3
                    id = (this.active_ids) & (this.f_id == 1) & this.pr_validity & this.system' == sys_c;
            end
            pr = this.pr(id,:);
        end
        
        function pr = pr2(this, flag_valid, sys_c)
            % get p_range 2 (Legacy)
            % SYNTAX this.pr1(<flag_valid>, <sys_c>)
            switch nargin
                case 1
                    id = (this.active_ids) & (this.f_id == 2);
                case 2
                    if flag_valid
                        id = (this.active_ids) & (this.f_id == 2) & this.pr_validity;
                    else
                        id = (this.active_ids) & (this.f_id == 2);
                    end
                case 3
                    id = (this.active_ids) & (this.f_id == 2) & this.pr_validity & this.system' == sys_c;
            end
            pr = this.pr(id,:);
        end
        
        function [ph, wl] = ph1(this, flag_valid, sys_c)
            % get phase 1 (Legacy)
            % SYNTAX this.ph1(<flag_valid>, <sys_c>)
            switch nargin
                case 1
                    id = (this.active_ids) & (this.f_id == 1);
                case 2
                    if flag_valid
                        id = (this.active_ids) & (this.f_id == 1) & this.pr_validity;
                    else
                        id = (this.active_ids) & (this.f_id == 1);
                    end
                case 3
                    id = (this.active_ids) & (this.f_id == 1) & this.pr_validity & this.system' == sys_c;
            end
            ph = this.ph(id,:);
            wl = this.wl(id);
        end
        
        function [ph, wl] = ph2(this, flag_valid, sys_c)
            % get phase 2 (Legacy)
            % SYNTAX this.ph1(<flag_valid>, <sys_c>)
            switch nargin
                case 1
                    id = (this.active_ids) & (this.f_id == 2);
                case 2
                    if flag_valid
                        id = (this.active_ids) & (this.f_id == 2) & this.pr_validity;
                    else
                        id = (this.active_ids) & (this.f_id == 2);
                    end
                case 3
                    id = (this.active_ids) & (this.f_id == 2) & this.pr_validity & this.system' == sys_c;
            end
            ph = this.ph(id,:);
            wl = this.wl(id);
        end
        
        function [ph, wl] = getPhGps(this, flag_valid)
            % get phase 2 (Legacy)
            % SYNTAX this.ph1(<flag_valid>, <sys_c>)
            switch nargin
                case 1
                    id = (this.active_ids) & (this.system == 'G')';
                case 2
                    if flag_valid
                        id = (this.active_ids) & (this.system == 'G')' & this.pr_validity;
                    else
                        id = (this.active_ids) & (this.system == 'G')';
                    end
            end
            ph = this.ph(id,:);
            wl = this.wl(id);
        end
        function [obs, idx] = getObs(this, flag, system, prn)
            % get observation and index corresponfing to the flag
            % SYNTAX this.getObsIdx(flag, <system>)
            if nargin > 3
                idx = this.getObsIdx(flag, system, prn);
            elseif nargin > 2
                idx = this.getObsIdx(flag, system);
            else
                idx = this.getObsIdx(flag);
            end
            obs = this.obs(idx,:);
        end
        function [idx] = getObsIdx(this, flag, system, prn)
            % get observation index corresponfing to the flag
            % SYNTAX this.getObsIdx(flag, <system>)
            idx = sum(this.obs_code(:,1:length(flag)) == repmat(flag,size(this.obs_code,1),1),2) == length(flag);
            if nargin > 2
                idx = idx & [this.system == system]';
            end
            if nargin > 3
                idx = idx & reshape(this.prn == prn,length(this.prn),1);
            end
            idx = find(idx);
            idx(idx==0)=[];
        end
        function [obs,idx] = getPrefObsCh(this, flag, system, max_obs_type)
            % get observation index corresponfing to the flag using best
            % channel according to the feinition in GPS_SS, GLONASS_SS
            % SYNTAX this.getObsIdx(flag, <system>)
            
            if length(flag)==3
                idx = sum(this.obs_code == repmat(flag,size(this.obs_code,1),1),2) == 3;
                idx = idx & [this.system == system]';
                %this.legger.addWarning(['Unnecessary Call obs_type already determined, use getObsIdx instead'])
                [obs,idx] = this.getObs(flag, system);
            elseif length(flag) >= 2
                flags = zeros(size(this.obs_code,1),3);
                sys_idx = [this.system == system]';
                sys = this.cc.getSys(system);
                band = find(sys.CODE_RIN3_2BAND == flag(2));
                if isempty(band)
                    this.logger.addWarning('Obs not found',200);
                    obs = [] ; idx = [];
                    return;
                end
                preferences = sys.CODE_RIN3_ATTRIB{band}; % get preferences
                sys_obs_code = this.obs_code(sys_idx,:); % get obs code for the given system
                sz =size(sys_obs_code,1);
                complete_flags = [];
                if nargin < 4
                    max_obs_type = length(preferences);
                end
                % find the betters flag present
                for j = 1 : max_obs_type
                    for i = 1:length(preferences)
                        if sum(sum(sys_obs_code == repmat([flag preferences(i)],sz,1),2)==3)>0
                            complete_flags = [complete_flags; flag preferences(i)];
                            preferences(i) = [];
                            break
                        end
                    end
                end
                if isempty(complete_flags)
                    this.logger.addWarning('Obs not found',200);
                    obs = [] ; idx = [];
                    return;
                end
                max_obs_type = size(complete_flags,1);
                idxes = [];
                prn = [];
                for j = 1 : max_obs_type
                    flags = repmat(complete_flags(j,:),size(this.obs_code,1),1);
                    idxes = [idxes  sum(this.obs_code == flags,2) == 3];
                    prn = unique( [prn; this.prn(idxes(: , end )>0)]);
                end
                
                n_opt = size(idxes,2);
                n_epochs = size(this.obs,2);
                obs = zeros(length(prn)*n_opt,n_epochs);
                flags = zeros(length(prn)*n_opt,3);
                for s = 1:length(prn) % for each satellite and each epoch find the best (but put them on diffrent lines)
                    sat_idx = sys_idx & this.prn==prn(s);
                    
                    tmp_obs = zeros(n_opt,n_epochs);
                    take_idx = ones(1,n_epochs)>0;
                    for i = 1 : n_opt
                        c_idx = idxes(:, i) & sat_idx;
                        if sum(c_idx)>0
                            obs((s-1)*n_opt+i,take_idx) = this.obs(c_idx,take_idx);
                            flags((s-1)*n_opt+i,:) = this.obs_code(c_idx,:);
                        end
                        take_idx = take_idx & obs((s-1)*n_opt+i,:) == 0;
                    end
                end
                prn = reshape(repmat(prn,1,n_opt)',length(prn)*n_opt,1);
                % remove all empty lines
                empty_idx = sum(obs==0,2) == n_epochs;
                obs(empty_idx,:) = [];
                prn(empty_idx,:) = [];
                flags(empty_idx,:) = [];
                flags=char(flags);
                idx = zeros(length(prn),1);
                for i = 1:length(prn)
                    idx(i) = find(sys_idx & this.prn == prn(i) & sum(this.obs_code == repmat(flags(i,:) ,size(this.obs_code,1) ,1),2) == 3);
                end
            else
                this.logger.addError(['Invalide length of obs code(' num2str(length(flag)) ') can not determine preferred observation'])
            end
        end
        function [obs, prn, obs_code] = getIonoFree(this, flag1, flag2, system, max_obs_type)
            % get Iono free combination for the two selcted measurements
            % SYNTAX [obs] = this.getIonoFree(flag1, flag2, system)
            if not(flag1(1)=='C' | flag1(1)=='L' | flag2(1)=='C' | flag2(1)=='L')
                rec.logger.addWarning('Can produce IONO free combination for the selcted observation')
                return
            end
            if flag1(1)~=flag2(1)
                rec.logger.addWarning('Incompatible observation type')
                return
            end
            if nargin <5
                max_obs_type = 1
            end
            [obs1, idx1] = this.getPrefObsCh(flag1, system, max_obs_type);
            [obs2, idx2] = this.getPrefObsCh(flag2, system, max_obs_type);
            
            prn1 = this.prn(idx1);
            prn2 = this.prn(idx2);
            
            common_prn = intersect(prn1, prn2);
            sset_idx1 = ismember(prn1 , common_prn);
            sset_idx2 = ismember(prn2 , common_prn);
            prn1 = prn1(sset_idx1);
            prn2 = prn2(sset_idx2);
            idx1 = idx1(sset_idx1);
            idx2 = idx2(sset_idx2);
            obs1 = obs1(sset_idx1,:);
            obs2 = obs2(sset_idx2,:);
            
            %%% find the longer idx and replicate th other one to match the
            %%% prn
            if length(idx1) > length(idx2)
                idx_tmp = zeros(size(idx1));
                obs_tmp = zeros(size(obs1));
                duplicate = prn1(1:end-1) == prn1(2:end);
                idx_tmp(~duplicate) = idx2;
                obs_tmp(~duplicate,:) = obs2;
                idx_tmp(duplicate) = idx_tmp(find(duplicate)+1);
                obs_tmp(duplicate,:) = obs_tmp(find(duplicate)+1,:);
                idx2 = idx_tmp;
                obs2 = obs_tmp;
            else
                idx_tmp = zeros(size(idx2));
                obs_tmp = zeros(size(obs2));
                duplicate = [prn2(1:end-1) == prn2(2:end); false];
                idx_tmp(~duplicate) = idx1;
                obs_tmp(~duplicate,:) = obs1;
                idx_tmp(duplicate) = idx_tmp(find(duplicate)+1);
                obs_tmp(duplicate,:) = obs_tmp(find(duplicate)+1,:);
                idx1 = idx_tmp;
                obs1 = obs_tmp;
            end
            %             obs1 = this.obs(idx1,:);
            %             obs2 = this.obs(idx2,:);
            prn = this.prn(idx1);
            
            wl1 = this.wl(idx1);
            wl2 = this.wl(idx2);
            
            if isempty(obs1)|isempty(obs2)
                obs = [];
                prn = [];
                return
            end
            
            
            % put zeros to NaN
            obs1(obs1 == 0) = NaN;
            obs2(obs2 == 0) = NaN;
            
            %gte wavelenghts
            inv_wl1 = repmat(1./this.wl(idx1),1,size(obs1,2)); %1/wl1;
            inv_wl2 = repmat(1./this.wl(idx2),1,size(obs2,2)); % 1/wl2;%
            obs = ((inv_wl1).^2 .* obs1 - (inv_wl2).^2 .* obs2)./ ( (inv_wl1).^2 - (inv_wl2).^2 );
            
            % set NaN to 0
            obs(isnan(obs)) = 0;
            obs_code = [this.obs_code(idx1,:) this.obs_code(idx2,:)];
        end
        function [obs, prn, obs_code] = getPrefIonoFree(this, obs_type, system)
            % get Preferred Iono free combination for the two selcted measurements
            % SYNTAX [obs] = this.getIonoFree(flag1, flag2, system)
            iono_pref = this.cc.getSys(system).IONO_FREE_PREF;
            is_present = zeros(size(iono_pref,1),1) < 1;
            for i = size(iono_pref,1)
                % check if there are onservation for the selected channel
                if sum(iono_pref(i,1) == this.obs_code(:,2) & iono_pref(i,1) == this.obs_code(:,1)) > 0 & sum(iono_pref(i,2) == this.obs_code(:,2) & iono_pref(i,1) == this.obs_code(:,1)) > 0
                    is_present(i) = true;
                end
            end
            iono_pref = iono_pref(is_present,:);
            [obs, prn, obs_code] = this.getIonoFree([obs_type iono_pref(1,1)], [obs_type iono_pref(1,2)], system);
        end
    end
    
    % ==================================================================================================================================================
    %  FUNCTIONS used as utilities
    % ==================================================================================================================================================
    methods (Access = public)
        function syncPrPh(this)
            % remove all the observations that are not present for both phase and pseudo-range
            % SYNTAX: this.syncPrPh()
            sat = ~isnan(this.pr) & ~isnan(this.ph);
            this.pr(~sat) = nan;
            this.ph(~sat) = nan;
        end
        
        function syncPhFreq(this, f_to_sync)
            % remove all the observations that are not present in all the specified frequencies
            % SYNTAX: this.syncFreq(f_to_sync)
            
            go_ids = unique(this.go_id);
            id_f = false(size(this.f_id));
            for f = 1 : numel(f_to_sync)
                id_f = id_f | this.f_id == f_to_sync(f);
            end
            for s = 1 : numel(go_ids)
                sat = (this.go_id == go_ids(s)) & id_f;
                if numel(sat) == 1
                    this.ph(sat, :) = nan;
                else
                    id_ko = sum(isnan(this.ph(sat, :))) > 0;
                    this.ph(sat, id_ko) = nan;
                end
            end
        end
        function GroupDelay(this, sgn)
            % DESCRIPTION. apply group delay corrections for code and pahse
            % measurement when a value if provided froma an external source
            % (Navigational file  or DCB file)
            for i = 1:size(this.rec2sat.cs.group_delays,2)
                if this.rec2sat.cs.group_delays(i) ~= 0
                    
                    idx = this.getObsIdx(this.rec2sat.cs.group_delays_flags(i,2:4),this.rec2sat.cs.group_delays_flags(i,1));
                    if ~isempty(idx)
                        for s = 1 : size(this.rec2sat.cs.group_delays,1)
                            sat_idx = find(this.prn(idx)== s);
                            sat_idx = idx(sat_idx);
                            this.obs(sat_idx,not(this.obs(idx,sat_idx)==0)) = this.obs(sat_idx,not(this.obs(idx,sat_idx)==0)) + sign(sgn) * this.rec2sat.cs.group_delays(s,i);
                        end
                    end
                end
            end
            
        end
        function applyGroupDelay(this)
            if this.group_delay_status == 0
                this.GroupDelay(1);
                this.group_delay_status = 1; %applied
            end
        end
        function removeGroupDelay(this)
            if this.group_delay_status == 1
                this.GroupDelay(-1);
                this.group_delay_status = 0; %applied
            end
        end
        function Dts(this,flag)
            % DESCRIPTION. apply clock satellite corrections for code and
            % pahse
            % IMPORTANT: if no clock is present delete the observation
            
            
            idx = [this.getObsIdx('C'); this.getObsIdx('L')];
            if isempty(this.obs_validity)
                this.obs_validity= false(size(this.obs,1),1);
            end
            for i = 1 : this.cc.getNumSat();
                prn = this.cc.prn(i);
                sys = this.cc.system(i);
                sat_idx = this.prn == prn & [this.system == sys]' & (this.obs_code(:,1) == 'C' | this.obs_code(:,1) == 'L');
                ep_idx = sum(this.obs(sat_idx,:) > 0) > 0;
                this.updateAvailIndex(ep_idx,i);
                dts_range = ( this.getDtS(i) + this.getRelClkCorr(i) ) * goGNSS.V_LIGHT;
                for o = find(sat_idx)'
                    obs_idx_l = this.obs(o,:) > 0;
                    obs_idx = find(obs_idx_l);
                    dts_idx = obs_idx_l(ep_idx);
                    if this.obs_code(o,1) == 'C'
                        this.obs(o, obs_idx_l) = this.obs(o,obs_idx_l) + sign(flag) * dts_range(dts_idx)';
                    else
                        this.obs(o, obs_idx_l) = this.obs(o,obs_idx_l) + sign(flag) * dts_range(dts_idx)'./this.wl(o);
                    end
                    dts_range_2 = dts_range(dts_idx);
                    nan_idx = obs_idx(find(isnan(dts_range_2)));
                    this.obs(o, nan_idx) = 0; 
                end
                
            end
            
            
        end
        function applyDts(this)
            if this.dts_delay_status == 0
                this.Dts(1);
                this.dts_delay_status = 1; %applied
            end
        end
        function removeDts(this)
            if this.dts_delay_status == 1
                this.Dts(-1);
                this.dts_delay_status = 0; %applied
            end
        end
        function [obs, prn, sys, flag] = getBestCodeObs(this);
            % INPUT:
            % OUPUT:
            %    obs = observations [n_obs x n_epoch];
            %    prn = satellite prn [n_obs x 1];
            %    sys = system [n_obs x 1];
            %    flag = flag of the observation [ n_obs x6] iono free
            %    combination are labeled with the obs code of both
            %    obeservations
            % DESCRIPTION: get "best" avaliable code or code combination
            % for the given system
            n_epoch = size(this.obs,2);
            obs = [];
            sys = [];
            prn = [];
            flag = [];
            for i=1:this.cc.getNumSat()
                sat_idx = this.getObsIdx('C',this.cc.system(i),this.cc.prn(i));
                sat_idx = sat_idx(this.obs_validity(sat_idx) );
                if ~isempty(sat_idx)
                    % get epoch for which iono free is possible
                    sat_obs = this.obs(sat_idx,:);
                    av_idx = sum((sat_obs > 0),1)>0;
                    freq = str2num(this.obs_code(sat_idx,2));
                    u_freq = unique(freq);
                    if length(u_freq)>1
                        sat_freq = (sat_obs > 0) .*repmat(freq,1,n_epoch);
                        u_freq_sat = zeros(length(u_freq),n_epoch);
                        for e = 1 : length(u_freq)
                            u_freq_sat(e,:) = sum(sat_freq == u_freq(e))>0;
                        end
                        iono_free = sum(u_freq_sat)>1;
                    else
                        iono_free = false(1,n_epoch);
                    end
                    freq_list = this.cc.getSys(this.cc.system(i)).CODE_RIN3_2BAND;
                    track_list = this.cc.getSys(this.cc.system(i)).CODE_RIN3_ATTRIB;
                    if sum(iono_free > 0)
                        %this.rec2sat.avail_index(:,i) = iono_free; % epoch for which observation is present
                        % find first freq obs
                        to_fill_epoch = iono_free;
                        first_freq = [];
                        f_obs_code = [];
                        ff_idx = zeros(n_epoch,1);
                        for f = 1 :length(freq_list)
                            track_prior = track_list{f};
                            for c = 1:length(track_prior)
                                if sum(to_fill_epoch) > 0
                                    [obs_tmp,idx_tmp] = this.getObs(['C' freq_list(f) track_prior(c)],this.cc.system(i),this.cc.prn(i));
                                    %obs_tmp(obs_tmp==0) = nan;
                                    if ~isempty(obs_tmp)
                                        first_freq = [first_freq; zeros(1,n_epoch)];
                                        first_freq(end, to_fill_epoch) = obs_tmp(to_fill_epoch);
                                        ff_idx(to_fill_epoch) = size(first_freq,1);
                                        f_obs_code = [f_obs_code; this.obs_code(idx_tmp,:)];
                                        to_fill_epoch = to_fill_epoch & (obs_tmp == 0);
                                    end
                                end
                            end
                        end
                        % find second freq obs
                        to_fill_epoch = iono_free;
                        second_freq = [];
                        s_obs_code = [];
                        sf_idx = zeros(n_epoch,1);
                        for f = 1 :length(freq_list)
                            track_prior = track_list{f};
                            for c = 1:length(track_prior)
                                if sum(to_fill_epoch) > 0
                                    [obs_tmp,idx_tmp] = this.getObs(['C' freq_list(f) track_prior(c)],this.cc.system(i),this.cc.prn(i));
                                    %obs_tmp = zero2nan(obs_tmp);
                                    
                                    % check if obs has been used already as first frequency
                                    if ~isempty(obs_tmp)
                                        
                                        ff_ot_i = find(sum(f_obs_code(:,1:2) == repmat(this.obs_code(idx_tmp,1:2),size(f_obs_code,1),1),2)==2);
                                        if ~isempty(ff_ot_i)
                                            obs_tmp(sum(first_freq(ff_ot_i,:),1)>0) = 0; % delete epoch where the obs has already been used for the first frequency
                                            
                                        end
                                        
                                       if sum(obs_tmp(to_fill_epoch)>0)>0 % if there is some new observation
                                            second_freq = [second_freq; zeros(1,n_epoch)];
                                            second_freq(end, to_fill_epoch) = obs_tmp(to_fill_epoch);
                                            sf_idx(to_fill_epoch) = size(second_freq,1);
                                            s_obs_code = [s_obs_code; this.obs_code(idx_tmp,:)];
                                            to_fill_epoch = to_fill_epoch & (obs_tmp == 0);
                                        end
                                    end
                                end
                            end
                        end
                        first_freq  = zero2nan(first_freq);
                        second_freq = zero2nan(second_freq);
                        % combine the two frequencies
                        for k = 1 : size(f_obs_code,1)
                            for y = 1 : size(s_obs_code,1)
                                inv_wl1 = 1/this.wl(this.getObsIdx(f_obs_code(k,:),this.cc.system(i),this.cc.prn(i)));
                                inv_wl2 = 1/this.wl(this.getObsIdx(s_obs_code(y,:),this.cc.system(i),this.cc.prn(i)));
%                                 if ((inv_wl1).^2 - (inv_wl2).^2) == 0
%                                     keyboard
%                                 end
                                    
                                obs_tmp = ((inv_wl1).^2 .* first_freq(k,:) - (inv_wl2).^2 .* second_freq(y,:))./ ( (inv_wl1).^2 - (inv_wl2).^2 );
                                obs_tmp(isnan(obs_tmp)) = 0;
                                if sum(obs_tmp>0)>0
                                    obs = [obs; obs_tmp];
                                    prn = [prn; this.cc.prn(i)];
                                    sys = [sys; this.cc.system(i)];
                                    flag = [flag; [f_obs_code(k,:) s_obs_code(y,:) 'I' ]];
                                end
                            end
                        end
                        %                     end
                        %                     if sum(xor(av_idx, iono_free))>0
                    else % do not mix iono free and not combined observations
                        % find best code
                        to_fill_epoch = av_idx;
                        %this.rec2sat.avail_index(:,i) = av_idx; % epoch for which observation is present
                        for f = 1 :length(freq_list)
                            track_prior = track_list{f};
                            for c = 1:length(track_prior)
                                if sum(to_fill_epoch) > 0
                                    [obs_tmp,idx_tmp] = this.getObs(['C' num2str(freq_list(f)) track_prior(c)],this.cc.system(i),this.cc.prn(i));
                                    if ~isempty(obs_tmp)
                                        obs = [obs; zeros(1,n_epoch)];
                                        obs(end,to_fill_epoch) = obs_tmp(to_fill_epoch);
                                        prn = [prn; this.cc.prn(i)];
                                        sys = [sys; this.cc.system(i)];
                                        flag = [flag; sprintf('%-7s',this.obs_code(idx_tmp,:))];
                                        to_fill_epoch = to_fill_epoch & (obs_tmp < 0);
                                    end
                                end
                            end
                        end
                        
                    end
                    
                end
            end
            %%% Remove obs for which coordinates of satellite are non
            %%% available
            for o = 1:length(prn)
                s = this.cc.getIndex(sys(o),prn(o));
                o_idx_l = obs(o,:)>0;
                times = this.time.getSubSet(o_idx_l);
                times.addSeconds(-obs(o,o_idx_l)'/Go_State.V_LIGHT); % add roucg time of flight
                xs = this.rec2sat.cs.coordInterpolate(times,s);
                to_remove = isnan(xs(:,1));
                o_idx = find(o_idx_l);
                to_remove = o_idx(to_remove);
                obs(o,to_remove) = 0;
                if sum(obs(o,:)) == 0 % if line has no more observation
                    obs(o,:) = [];
                    prn(o) = [];
                    sys(o) = [];
                    flag(o,:) = [];
                end
            end
        end
        function initPositioning(this)
            % SYNTAX:
            %   this.initPositioning();
            %
            % INPUT:
            % OUTPUT:
            %
            % DESCRIPTION:
            %   Get postioning using code observables
            
            this.rec2sat.err_tropo = zeros(this.time.length, this.cc.getNumSat());
            this.rec2sat.err_iono  = zeros(this.time.length, this.cc.getNumSat());
            this.rec2sat.solid_earth_corr  = zeros(this.time.length, this.cc.getNumSat());
            
            % if not applied apply gruop delay
            %this.applyGroupDelay();
            this.applyDts();
            
            % get best observation for all satellites and all epochs
            [obs, prn, sys, flag] = this.getBestCodeObs;
%             [obs, prn, flag] = this.getIonoFree('C1','C2','G',1);
%             sys = char('G' * ones(size(prn)));
            
            iono_free = flag(1,1) == 'I';
            %                [obs, idx] = this.getObs('C1');
            %                prn = this.prn(idx);
            %                flag = this.obs_code(idx,:);
            %               sys = this.system(idx)';
            approx_pos_unknown = true;
            opt.rid_ep = false; %do not estimate channel dipendent error at each epoch
            
            if  approx_pos_unknown
                this.xyz = [0 0 0];
                if sum(sum(obs,1)) > 1000
                    % sub sample observations
                    sub_sample = true;
                    idx_ss = 1:100;%(1: round(size(obs,2) / 200):size(obs,2));
                    idx_ss_l = false(1, size(obs,2));
                    idx_ss_l(1:1000) = true;
                    
                    obs_ss = zeros(size(obs));
                    obs_ss(:,idx_ss_l) = obs(:,idx_ss_l);
                    prn_ss =  prn;
                    sys_ss = sys;
                    flag_ss = flag;
                    
                    
                    
                    % remove line that might be empty
                    empty_sat = sum(obs_ss,2) == 0;
                    obs_ss(empty_sat, :) = [];
                    prn_ss(empty_sat, :)  = [];
                    flag_ss(empty_sat, :) = [];
                    sys_ss(empty_sat, :)  = [];
                end
                cut_off = 10;
                % first estimation noatmosphere
                opt.coord_corr = 1;
                opt.max_it = 10;
                if sub_sample
                    this.codePositionig(obs_ss, prn_ss, sys_ss, flag_ss, opt);
                    [obs_ss, sys_ss, prn_ss, flag_ss] = this.removeUndCutOff(obs_ss, sys_ss, prn_ss, flag_ss, cut_off);
                else
                    this.codePositionig(obs, prn, sys, flag, opt);
                end
                 %%% remove obs under cu off
                [obs, sys, prn, flag] = this.removeUndCutOff(obs, sys, prn, flag, cut_off);
                % update atmosphere
                this.updateErrTropo('all', 1);
                if ~iono_free
                    this.updateErrIono();
                end
                
               
                % second estimation with atmosphere
                opt.coord_corr = 1;
                opt.max_it = 10;
                if sub_sample
                    this.codePositionig(obs_ss, prn_ss, sys_ss, flag_ss, opt);
                else
                    this.codePositionig(obs, prn, sys, flag, opt);
                end
            end
            if sub_sample
                % update avalibilty index
                for s = 1:this.cc.getNumSat()
                    idx_sat = prn == this.cc.prn(s) & sys == this.cc.system(s);
                    if sum(idx_sat) >0
                        this.updateAvailIndex(sum(obs(idx_sat,:),1),s)
                    end
                end
            else
                cut_off = 10;
                [obs, sys, prn, flag] = this.removeUndCutOff(obs, sys, prn, flag, cut_off);
            end
            % update Atmosphere Corrections
            this.updateErrTropo('all', 1);
            if ~iono_free
                this.updateErrIono();
            end
            % update solid earth corrections
            this.updateSolidEarthCorr();
            % final estimation
            cut_off = 10;
            opt.max_it = 1;
            opt.coord_corr = 0.1;
            opt.no_pos = true;
            
            this.codePositionig(obs, prn, sys, flag, opt); % get a first estimation of receiver clock offset to get correct orbit
            opt.no_pos = false;
            this.codePositionig(obs, prn, sys, flag, opt);
        end
        function codePositionig(this, obs, prn, sys, flag, opt)
            % INPUT: 
            %   opt: structure with options of the LS adjustement
            %        .coord_corr : stop if coordinate correction goes under
            %        the paramter
            %        .max_it : maximum number of iterations
            % DESCRITION compute the postion of the receiver based on code
            % measurements
            
            if nargin < 5
                opt.coord_corr = 0.1;
                opt.max_it = 10;
                opt.no_pos = false;
            end
            if ~isfield(opt,'no_pos')
                opt.no_pos = false;
            end
            if ~isfield(opt,'rid_ep')
                opt.rid_ep  = false;
            end
            n_epochs         = this.time.length;
            n_valid_epochs   = sum(sum(obs,1)>0);
            
            code_bias_flag   = cellstr([sys flag]);
            u_code_bias_flag = unique(code_bias_flag);
            % initialize dtr
            
            
            
            n_obs_ch         = zeros(size(u_code_bias_flag));
            n_ep_ch          = zeros(size(u_code_bias_flag));
            ch_idx_ep        = zeros(length(u_code_bias_flag),n_epochs);
            for i = 1 : length(n_obs_ch)
                ch_idx_sat = sum([sys flag] == repmat( sprintf('%-8s',u_code_bias_flag{i}),length(sys),1),2) == 8;
                n_obs_ch(i) = sum((ch_idx_sat).*sum(obs > 0, 2)); % find number of observation per channel
                ch_idx_ep(i,:) = sum(obs(ch_idx_sat,:),1) > 0;
                n_ep_ch(i) = sum(ch_idx_ep(i,:)); % find number of observation per channel
            end
            % sort the channel variables depending on the number of
            % observables
            [n_obs_ch_s, b] = sort(n_obs_ch,'descend');
            u_code_bias_flag = u_code_bias_flag(b);
            n_ep_ch = n_ep_ch(b,:);
            ch_idx_ep = ch_idx_ep(b,:);
           
            
            if opt.rid_ep
                this.dtR = zeros(this.time.length,length(u_code_bias_flag));
                this.dtR_obs_code = u_code_bias_flag;
            else
                this.dtR = zeros(this.time.length,1);
                this.rid = zeros(1, length(u_code_bias_flag)-1);
                this.dtR_obs_code = u_code_bias_flag;
                
                
            end
            
            
            n_tot_obs = sum(sum(obs>0));
            
            % initialize LS solver
            ls_solver = Least_Squares_Manipulator();
            ls_solver.y0 = zeros(n_tot_obs,1);
            ls_solver.b = zeros(n_tot_obs,1);
            ls_solver.y0_epoch = zeros(n_tot_obs,1);
            ls_solver.Q = speye(n_tot_obs);
            x = [999 999 999];
            
            iono_free = true; %to be removed
            
            if this.static == 1
                %ls_solver.A =sparse(n_tot_obs,3+n_valid_epochs+sum(n_ep_ch(2:end))); %version with reference clock
                if opt.rid_ep
                    n_par = 3+sum(n_ep_ch(1:end));
                    ls_solver.A = spalloc(n_tot_obs,n_par,round(n_par*0.1));
                else
                    n_par = 3+n_valid_epochs+length(u_code_bias_flag)-1;
                    ls_solver.A = spalloc(n_tot_obs,n_par,round(n_par*0.1));
                end
                n_it = 0;
                while max(abs(x(1:3))) > opt.coord_corr &   n_it < opt.max_it
                    n_it = n_it + 1;
                    ls_solver.clearUpdated();
                    % fill the a matrix
                    oc = 1; % obervation counter
                    for i = 1 : this.cc.getNumSat();
                        c_sys = this.cc.system(i);
                        c_prn = this.cc.prn(i);
                        idx_sat = sys == c_sys & prn == c_prn;
                        idx_sat_i = find(idx_sat);
                        if sum(idx_sat) > 0 % if we have an obesrvation for the satellite
                            c_obs = obs(idx_sat,:);
                            
                            c_obs_idx = c_obs > 0;
                            c_l_obs = colFirstNonZero(c_obs); %all best obs one one line
                            idx_obs = c_l_obs > 0; %epoch with obseravtion from the satellite
                           
                            
                            n_obs_sat = sum(sum(c_obs>0));
                            %update time of flight times
                            this.updateAvailIndex(c_l_obs,i); 
                            this.updateTOT(c_l_obs,i); % update time of travel
                            %----- OLD WAY --------------------
%                             
%                             % CORRECT THE OBSERVATIONS
%                             % iono corr
%                             if ~iono_free
%                                 err_iono = repmat(this.rec2sat.err_iono',size(c_obs,1),1); % c_obs = bsxfun(@minus, c_obs, err_iono);
%                                 c_obs(c_obs_idx) = c_obs(c_obs_idx) - err_iono(c_obs_idx);
%                             end
%                             % tropo corr
%                             err_tropo = repmat(this.rec2sat.err_tropo(:,i)',size(c_obs,1),1);
%                             c_obs(c_obs_idx) = c_obs(c_obs_idx) - err_tropo(c_obs_idx);
%                             % solid earth corrections
%                             solid_earth_corr = repmat(this.rec2sat.solid_earth_corr(:,i)',size(c_obs,1),1);
%                             c_obs(c_obs_idx) = c_obs(c_obs_idx) - solid_earth_corr(c_obs_idx);
%                             
%                             
%                             XS = this.getXSTxRot(i); %get satellite positions at transimssion time including earth rotation during the travel time
%                             XR = repmat(this.xyz,sum(c_l_obs>0),1);
%                             XS = XS - XR;
%                             dist = sqrt(sum(XS.^2,2));
                            %--------------------------------------------------------
                            freq = flag(idx_sat_i(1), 7);
                            if freq == ' ';
                                freq = flag(idx_sat_i(1), 2);
                            end
                            [dist, XS] = this.getSyntObs(freq,i); %%% consider multiple combinations on the same satellite, not handdled yet
                            dist(dist==0) = [];
                           

                             XS_norm = rowNormalize(XS);
                            
                            
                            for j = 1 : size(c_obs,1) % for observation of the satellite
                                idx_ep = c_obs(j,:) > 0; % epoch with observation from the channel
                                idx_tmp2 = idx_ep(idx_obs); 
                               
                                
                                
                                
                                n_obs = sum(idx_ep);
                                ls_solver.y0(oc:(oc+n_obs-1)) = c_obs(j,idx_ep);
                                ls_solver.b(oc:(oc+n_obs-1))  = dist(idx_tmp2);
                                ls_solver.y0_epoch(oc:(oc+n_obs-1)) = find(idx_ep);
                                if ~opt.no_pos 
                                   ls_solver.A(oc:(oc+n_obs-1),1:3)  = - XS_norm(idx_tmp2,:);
                                end
                                
                                
                                % clocks
                                % PLEASE COMMENT MORE
                                if sum(idx_sat) > 1 % case more observation on one satellite
                                    idx_tmp4 = find(idx_sat);
                                    idx_tmp4 = idx_tmp4(j);
                                    flag_tmp = code_bias_flag{idx_tmp4};
                                else
                                    flag_tmp = code_bias_flag{idx_sat};
                                end
                                % find the channel of the observations 
                                channel = find(sum(cell2mat(u_code_bias_flag) == repmat(flag_tmp,length(u_code_bias_flag),1),2) == length(flag_tmp), 1, 'first');
                                idx_ep_2 = idx_ep(sum(obs,1)>0);
                                if opt.rid_ep
                                    %idx_tmp3 = sub2ind(size(ls_solver.A),oc:(oc+n_obs-1) ,3+n_valid_epochs+sum(n_ep_ch(2:channel-1))+find(idx_ep_2(ch_idx_ep(channel,:) > 0)));
                                    idx_tmp3 = sub2ind(size(ls_solver.A),oc:(oc+n_obs-1) , 3+sum(n_ep_ch(1:channel-1))+find(idx_ep_2(ch_idx_ep(channel,:) > 0)));
                                    ls_solver.A(idx_tmp3) = 1;

                                else
                                     idx_tmp3 = sub2ind(size(ls_solver.A),oc:(oc+n_obs-1) ,3+find(idx_ep_2));
                                     ls_solver.A(idx_tmp3)  = 1; % reference clock
                                     if channel ~= 1
                                         ls_solver.A(oc:(oc+n_obs-1),3+n_valid_epochs+channel -1 )  = 1; % channel dipendent code bias
                                     end
                                end
                                oc = oc + n_obs;
                                
                                
                                
                            end
                            
                            
                            
                        end
                    end
                    %ls_solver.sortSystemByEpoch();
                    if opt.no_pos 
                         [x, res] = ls_solver.solve([4:size(ls_solver.A,2)]);
                         x = [zeros(3,1) ; x];
                    else
                         [x, res] = ls_solver.solve();
                    end
                    this.xyz = this.xyz + x(1:3)';
                    %
                    if opt.rid_ep
                    for i = 1:length(u_code_bias_flag)
                        %this.dtR(ch_idx_ep(i,:) > 0,i) = x((( n_valid_epochs + sum(n_ep_ch(2:i-1))) : (n_valid_epochs + sum(n_ep_ch(2:i)) -1 ) ) + 3) / Go_State.V_LIGHT;
                        this.dtR(ch_idx_ep(i,:) > 0,i) = x(((sum(n_ep_ch(1:i-1))) : (sum(n_ep_ch(1:i)) -1 ) ) + 4) / Go_State.V_LIGHT;
                    end
                    else
                        this.dtR(sum(obs,1) > 0,1,1) = x((1 : n_valid_epochs) + 3) / Go_State.V_LIGHT;
                        this.rid = x((n_valid_epochs + 4) : end) / Go_State.V_LIGHT;
                    end
                    
                end
                %keyboard
            else
            end
        end
        function [range, XS_loc] = getSyntObs(this,  obs_type, sat)
            % DESCRIPTION: get the estimate of one measurmenet based on the
            % current postion
            % INPUT: 
            %   obs_type; type of obs I(ionofree) 1(first system freqeuncy) 2(second sytem frequency) 3 (third system frequency) 
            n_epochs = size(this.obs, 2);
            n_sat = this.cc.getNumSat();
            if isnumeric(obs_type)
                obs_type = num2str(obs_type);
            end
            if nargin < 3
                range = zeros(n_sat, n_epochs);
                for sat = 1 : n_sat
                    range(sat, :) = this.getSyntObs(obs_type, sat);
                end
                XS_loc = [];
            else
                sat_idx = this.rec2sat.avail_index(:, sat);
                XS = this.getXSTxRot(sat);
                XS_loc = nan(n_epochs, 3);
                XS_loc(sat_idx,:) = XS;
                if size(this.xyz,1) == 1
                    XR = repmat(this.xyz, n_epochs, 1);
                else
                    XR = this.xyz;
                end
                XS_loc = XS_loc - XR;
                range = sqrt(sum(XS_loc.^2,2));
                sys = this.cc.system(sat);
                switch obs_type
                    case 'I'
                            iono_factor = 0;
                    case '1'
                            iono_factor = 1;
                    otherwise
                            iono_factors = this.cc.getSys(sys).getIonoFactor([1 str2num(obs_type)]);
                            iono_factor = iono_factors.alpha2 / iono_factors.aplha1;
                            
                end
                range = range + this.rec2sat.err_tropo(:,sat) + iono_factor * this.rec2sat.err_iono(:,sat) + this.rec2sat.solid_earth_corr(:,sat);
                
                XS_loc(isnan(range),:) = [];
                %range = range';
                range = nan2zero(range)';
                
                
            end
            
        end
        function [obs, sys, prn, flag] = removeUndCutOff(this, obs, sys, prn, flag, cut_off)
            % DESCRIPTION: remove obs under cut off
            for i = 1 : length(prn);
                sat = this.cc.getIndex(sys(i),prn(i));
                
                
                idx_obs = obs(i,:) > 0;
                this.updateAvailIndex(idx_obs, sat);
                XS = this.getXSTxRot(sat);
                
                [~ , el] = this.getAzimuthElevation(XS);
                
                idx_obs_f = find(idx_obs);
                el_idx = el < cut_off;
                idx_obs_f = idx_obs_f( el_idx );
                obs(i,idx_obs_f) = 0;
            end
            %%% remove possibly generated empty lines 
            empty_idx = sum(obs >0,2) == 0;
            obs(empty_idx,:) = [];
            sys(empty_idx,:) = [];
            prn(empty_idx,:) = [];
            flag(empty_idx,:) = [];
        end
        
        
    end
    
    % ==================================================================================================================================================
    %  STATIC FUNCTIONS used as utilities
    % ==================================================================================================================================================
    methods (Static, Access = public)
        
        function syncronize2receivers(rec1, rec2)
            % remove all the observations that are not present for both phase and pseudo-range between two receivers
            if (rec1.n_freq == 2) && (rec2.n_freq == 2)
                sat = ~isnan(rec1.pr(:,:,1)) & ~isnan(rec1.pr(:,:,2)) & ~isnan(rec1.ph(:,:,1)) & ~isnan(rec1.ph(:,:,2)) & ...
                    ~isnan(rec2.pr(:,:,1)) & ~isnan(rec2.pr(:,:,2)) & ~isnan(rec2.ph(:,:,1)) & ~isnan(rec2.ph(:,:,2));
            else
                sat = ~isnan(rec1.pr(:,:,1)) & ~isnan(rec1.ph(:,:,1)) & ...
                    ~isnan(rec2.pr(:,:,1)) & ~isnan(rec2.ph(:,:,1));
            end
            rec1.pr(~sat) = nan;
            rec1.ph(~sat) = nan;
            rec2.pr(~sat) = nan;
            rec2.ph(~sat) = nan;
        end
        
        function [y0, pc, wl, ref] = prepareY0(trg, mst, lambda, pivot)
            % prepare y0 and pivot_correction arrays (phase only)
            % SYNTAX: [y0, pc] = prepareY0(trg, mst, lambda, pivot)
            % WARNING: y0 contains also the pivot observations and must be reduced by the pivot corrections
            %          use composeY0 to do it
            y0 = [];
            wl = [];
            pc = [];
            i = 0;
            for t = 1 : trg.n_epo
                for f = 1 : trg.n_freq
                    sat_pr = trg.p_range(t,:,f) & mst.p_range(t,:,f);
                    sat_ph = trg.phase(t,:,f) & mst.phase(t,:,f);
                    sat = sat_pr & sat_ph;
                    pc_epo = (trg.phase(t, pivot(t), f) - mst.phase(t, pivot(t), f));
                    y0_epo = ((trg.phase(t, sat, f) - mst.phase(t, sat, f)));
                    ref = median((trg.phase(t, sat, f) - mst.phase(t, sat, f)));
                    wl_epo = lambda(sat, 1);
                    
                    idx = i + (1 : numel(y0_epo))';
                    y0(idx) = y0_epo;
                    pc(idx) = pc_epo;
                    wl(idx) = wl_epo;
                    i = idx(end);
                end
            end
        end
        
        function y0 = composeY0(y0, pc, wl)
            % SYNTAX: y0 = composeY0(y0, pc, wl)
            y0 = serialize((y0 - pc) .* wl);
            y0(y0 == 0) = []; % remove pivots
        end
        
        
    end
    
    % ==================================================================================================================================================
    %  FUNCTIONS TO GET SATELLITE RELATED PARAMETER
    % ==================================================================================================================================================
    methods
        function time_tx = getTimeTx(this,sat)
            % SYNTAX:
            %   this.getTimeTx(epoch);
            %
            % INPUT:
            % OUTPUT:
            %   time_tx = transmission time
            %   time_tx =
            %
            % DESCRIPTION:
            %   Get Transmission time
            idx = this.rec2sat.avail_index(:, sat) > 0;
            time_tx = this.time.getSubSet(idx);
            time_tx.addSeconds(-this.rec2sat.tot(idx, sat));
            
            
        end
        function updateTOT(this, obs, sat)
            % SYNTAX:
            %   this.updateTOT(time_rx, dtR);
            %
            % INPUT:
            %
            % OUTPUT:
            % DESCRIPTION:
            %   Compute the signal time of travel.
            if isempty(this.rec2sat.tot)
                this.rec2sat.tot = zeros(size(this.rec2sat.avail_index));
            end
            idx = this.rec2sat.avail_index(:,sat) > 0;
            this.rec2sat.tot(idx, sat) =  ( obs(idx)' + this.rec2sat.err_tropo(idx,sat) + this.rec2sat.err_iono(idx,sat) )/ goGNSS.V_LIGHT + this.dtR(idx,1) ;
            
        end
        function updateAvailIndex(this, obs, sat)
            % DESCRIPTION: upadte avaliabilty of measurement on staellite
            if isempty(this.rec2sat.avail_index)
                this.rec2sat.avail_index = false(this.time.length, this.cc.getNumSat());
            end
            this.rec2sat.avail_index(:,sat) = obs > 0;
        end
        function time_of_travel = getTOT(this)
            % SYNTAX:
            %   this.getTraveltime()
            % INPUT:
            % OUTPUT:
            %   time_of_travel   = time of travel
            % DESCRIPTION:
            %   Compute the signal transmission time.
            time_of_travel = this.tot;
        end
        function dtS = getDtS(this, sat)
            % SYNTAX:
            %   this.getDtS(time_rx)
            %
            % INPUT:
            %   time_rx   = reception time
            %
            % OUTPUT:
            %   dtS     = satellite clock errors
            % DESCRIPTION:
            %   Compute the satellite clock error.
            if nargin < 2
                dtS = zeros(size(this.rec2sat.avail_index));
                for s = 1 : size(dtS)
                    dtS(this.rec2sat.avail_index(:,s)) = this.rec2sat.cs.clockInterpolate(this.time(this.rec2sat.avail_index(:,s)),s);
                end
            else
                idx = this.rec2sat.avail_index(:,sat) > 0;
                dtS = this.rec2sat.cs.clockInterpolate(this.time.getSubSet(idx), sat);
            end
            
        end
        function dtRel = getRelClkCorr(this, sat)
            % DESCRIPTION : get clock offset of the satellite due to
            % special relativity (eccntrcity term)
            idx = this.rec2sat.avail_index(:,sat) > 0;
            [X,V] = this.rec2sat.cs.coordInterpolate(this.time.getSubSet(idx),sat);
            dtRel = -2 * sum(conj(X) .* V,2) / (goGNSS.V_LIGHT ^ 2); % Relativity correction (eccentricity velocity term)
        end
        
        
        function [XS_tx_r ,XS_tx] = getXSTxRot(this, sat)
            % SYNTAX:
            %   [XS_tx_r ,XS_tx] = this.getXSTxRot( time_rx, cc)
            %
            % INPUT:
            % time_rx = receiver time
            % cc = Constellation Collector
            % OUTPUT:
            % XS_tx = satellite position computed at trasmission time
            % XS_tx_r = Satellite postions at transimission time rotated by earth rotation occured
            % during time of travel
            % DESCRIPTION:
            %   Compute satellite positions at transmission time and rotate them by the earth rotation
            %   occured during time of travel of the signal
            [XS_tx] = this.getXSTx(sat);
            [XS_tx_r]  = this.earthRotationCorrection(XS_tx, sat);
        end
        function [XS_tx] = getXSTx(this, sat)
            % SYNTAX:
            %   [XS_tx_frame , XS_rx_frame] = this.getXSTx()
            %
            % INPUT:
            %  obs : [1x n_epochs] pseudi range observations
            %  sta : index of the satellite
            % OUTPUT:
            % XS_tx = satellite position computed at trasmission time
            % DESCRIPTION:
            % Compute satellite positions at trasmission time
            time_tx = this.getTimeTx(sat);
            [XS_tx, ~] = this.rec2sat.cs.coordInterpolate(time_tx,sat);
            
            
            %                 [XS_tx(idx,:,:), ~] = this.rec2sat.cs.coordInterpolate(time_tx);
            %             XS_tx  = zeros(size(this.rec2sat.avail_index));
            %             for s = 1 : size(XS_tx)
            %                 idx = this.rec2sat.avail_index(:,s);
            %                 %%% compute staeliite position a t trasmission time
            %                 time_tx = this.time.subset(idx);
            %                 time_tx = time_tx.time_diff - this.rec2sat.tot(idx,s)
            %                 [XS_tx(idx,:,:), ~] = this.rec2sat.cs.coordInterpolate(time_tx);
            %             end
        end
        function [XS_r] = earthRotationCorrection(this, XS, sat)
            % SYNTAX:
            %   [XS_r] = this.earthRotationCorrection(XS)
            %
            % INPUT:
            %   XS      = positions of satellites
            %   time_rx = receiver time
            %   cc      = Constellation Collector
            %   sat     = satellite
            % OUTPUT:
            %   XS_r    = Satellite postions rotated by earth roattion occured
            %   during time of travel
            % DESCRIPTION:
            %   Rotate the satellites position by the earth rotation
            %   occured during time of travel of the signal
            
            %%% TBD -> consider the case XS and travel_time does not match
            XS_r = zeros(size(XS));
            
            idx = this.rec2sat.avail_index(:,sat) > 0;
            travel_time = this.rec2sat.tot(idx,sat);
            sys = this.cc.system(sat);
            switch char(sys)
                case 'G'
                    omegae_dot = this.cc.gps.ORBITAL_P.OMEGAE_DOT;
                case 'R'
                    omegae_dot = this.cc.glo.ORBITAL_P.OMEGAE_DOT;
                case 'E'
                    omegae_dot = this.cc.gal.ORBITAL_P.OMEGAE_DOT;
                case 'C'
                    omegae_dot = this.cc.bds.ORBITAL_P.OMEGAE_DOT;
                case 'J'
                    omegae_dot = this.cc.qzs.ORBITAL_P.OMEGAE_DOT;
                case 'I'
                    omegae_dot = this.cc.irn.ORBITAL_P.OMEGAE_DOT;
                otherwise
                    Logger.getInstance().addWarning('Something went wrong in satellite_positions.m\nUnrecognized Satellite system!\n');
                    omegae_dot = this.cc.gps.ORBITAL_P.OMEGAE_DOT;
            end
            omega_tau = omegae_dot * travel_time;
            xR  = [cos(omega_tau)    sin(omega_tau)];
            yR  = [-sin(omega_tau)    cos(omega_tau)];
            XS_r(:,1) = sum(xR .* XS(:,1:2),2); % X
            XS_r(:,2) = sum(yR .* XS(:,1:2),2); % Y
            XS_r(:,3) = XS(:,3); % Z
            
            
        end
        function  updateErrTropo(this, sat, flag)
            %INPUT:
            % sat : number of sat
            % flag: flag of the tropo model
            %DESCRIPTION: update the tropospheric correction
            if isempty(this.rec2sat.err_tropo)
                this.rec2sat.err_tropo = zeros(size(this.rec2sat.avail_index));
            end
            if nargin < 2 | strcmp(sat,'all')
                if nargin < 3 
                        flag = this.state.tropo_model;
                end
                for s = 1 : size(this.rec2sat.avail_index,2)
                    this.updateErrTropo(s, flag);
                end
            else
                this.rec2sat.err_tropo(:, sat) = 0;
                %%% compute lat lon
                [~, lat, h, lon] = cart2geod(this.xyz(:,1), this.xyz(:,2), this.xyz(:,3));
                idx = this.rec2sat.avail_index(:,sat) > 0;
                if sum(idx)>0
                    XS = this.rec2sat.cs.coordInterpolate(this.time.getSubSet(idx), sat);
                    %%% compute az el
                    if size(this.xyz,1)>1
                        [az, el] = this.getAzimuthElevation(this.xyz(idx ,:) ,XS);
                    else
                        [az, el] = this.getAzimuthElevation(XS);
                    end
                    if nargin < 3 
                        flag = this.state.tropo_model;
                    end
                    switch flag
                        case 0 %no model
                            
                        case 1 %Saastamoinen with standard atmosphere
                            this.rec2sat.err_tropo(idx, sat) = Atmosphere.saastamoinen_model(lat, lon, h, el);
                            
                        case 2 %Saastamoinen with GPT
                            time = this.time.getGpsTime();
                            lat_t = zeros(size(idx)); lon_t = zeros(size(idx)); h_t = zeros(size(idx)); el_t = zeros(size(idx));
                            lat_t(idx) = lat; lon_t(idx) = lon; h_t(idx) = h; el_t(idx) = el;
                            for e = 1 : size(idx,1)
                                if idx(e) > 0
                                    [gps_week, gps_sow, gps_dow] = this.time.getGpsWeek(e);
                                    this.rec2sat.err_tropo(e, sat) = Atmosphere.saastamoinen_model_GPT(time(e), lat_t(e), lon_t(e), h_t(e), el_t(e));
                                end
                            end
                            
                    end
                end
            end
            
        end
        function updateErrIono(this, sat)
            if isempty(this.rec2sat.err_iono)
                this.rec2sat.err_iono = size(this.rec2sat.avail_index);
            end
            if nargin < 2
                for s = 1 : size(this.rec2sat.avail_index,2)
                    this.updateErrIono(s);
                end
            else
                idx = this.rec2sat.avail_index(:,sat) > 0; %epoch for which satellite is present
                if sum(idx) > 0
                    
                    XS = this.rec2sat.cs.coordInterpolate(this.time.getSubSet(idx), sat);
                    %%% compute lat lon
                    [~, lat, ~, lon] = cart2geod(this.xyz(:,1), this.xyz(:,2), this.xyz(:,3));
                    %%% compute az el
                    if size(this.xyz,1)>1
                        [az, el] = this.getAzimuthElevation(this.xyz(idx,:) ,XS);
                    else
                        [az, el] = this.getAzimuthElevation(XS);
                    end
                    
                    
                    switch this.state.iono_model
                        case 0 %no model
                            this.rec2sat.err_iono(idx,sat) = zeros(size(el));
                        case 1 %Geckle and Feen model
                            %corr = simplified_model(lat, lon, az, el, mjd);
                        case 2 %Klobuchar model
                            [week, sow] = time2weektow(this.time.getSubSet(idx).getGpsTime());
                            if ~isempty(this.rec2sat.cs.iono )
                                this.rec2sat.err_iono(idx,sat) = Atmosphere.klobuchar_model(lat, lon, az, el, sow, this.rec2sat.cs.iono);
                            else
                                this.logger.addWarning('No klobuchar parameter found, iono correction not computed');
                            end
                            
                    end
                end
            end
        end
        function updateSolidEarthCorr(this, sat)
            %DESCRIPTION: upadte the correction related to solid earth
            % solid tides, ocean loading, pole tides.
            if isempty(this.rec2sat.solid_earth_corr)
                this.rec2sat.solid_earth_corr = zeros(size(this.rec2sat.avail_index));
            end
            if nargin < 2
                
                for s = 1 : size(this.rec2sat.avail_index,2)
                    this.updateSolidEarthCorr(s);
                end
            else
                this.rec2sat.solid_earth_corr(:,sat) = this.computeSolidTideCorr(sat);% + this.computeOceanLoading(sat) + this.getPoleTideCorr(sat);
            end
        end
        function solid_earth_corr = computeSolidTideCorr(this, sat)
            
            % SYNTAX:
            %   [stidecorr] = this.getSolidTideCorr();
            %
            % INPUT:
            % 
            % OUTPUT:
            %   stidecorr = solid Earth tide correction terms (along the satellite-receiver line-of-sight)
            %
            % DESCRIPTION:
            %   Computation of the solid Earth tide displacement terms.
            if nargin < 2
                solid_earth_corr = zeros(size(this.rec2sat.avail_index));
                for s = 1 : size(this.rec2sat.avail_index,2)
                    solid_earth_corr(:,s) = this.updateSolidTideCorr(s);
                end
            else
                XR = this.xyz();
                if (nargin < 6)
                    [~, lam, ~, phiC] = cart2geod(XR(1,1), XR(1,2), XR(1,3));
                end
                %north (b) and radial (c) local unit vectors
                b = [-sin(phiC)*cos(lam); -sin(phiC)*sin(lam); cos(phiC)];
                c = [+cos(phiC)*cos(lam); +cos(phiC)*sin(lam); sin(phiC)];
                
                %interpolate sun moon and satellites
                idx_sat = this.rec2sat.avail_index(:,sat);
                time = this.time.getSubSet(idx_sat);
                [X_sun, X_moon]  = this.rec2sat.cs.sunMoonInterpolate(time);
                XS               = this.rec2sat.cs.coordInterpolate(time, sat);
                %receiver geocentric position
                XR_n = norm(XR);
                XR_u = repmat(XR / XR_n,time.length,1);
                XR   = repmat(XR,time.length, 1);
                
                %sun geocentric position
                X_sun_n = repmat(sqrt(sum(X_sun.^2,2)),1,3);
                X_sun_u = X_sun ./ X_sun_n;
                
                %moon geocentric position
                X_moon_n = repmat(sqrt(sum(X_moon.^2,2)),1,3);
                X_moon_u = X_moon ./ X_moon_n;
                
                %latitude dependence
                p = (3*sin(phiC)^2-1)/2;
                
                %gravitational parameters
                GE = goGNSS.GM_GAL; %Earth
                GS = GE*332946.0; %Sun
                GM = GE*0.01230002; %Moon
                
                %Earth equatorial radius
                R = 6378136.6;
                
                %nominal degree 2 Love number
                H2 = 0.6078 - 0.0006*p;
                %nominal degree 2 Shida number
                L2 = 0.0847 + 0.0002*p;
                
                %solid Earth tide displacement (degree 2)
                Vsun  = repmat(sum(conj(X_sun_u) .* XR_u, 2),1,3);
                Vmoon = repmat(sum(conj(X_moon_u) .* XR_u, 2),1,3);
                r_sun2  = (GS*R^4)./(GE*X_sun_n.^3) .*(H2.*XR_u.*(1.5*Vsun.^2  - 0.5)+ 3*L2*Vsun .*(X_sun_u  - Vsun .*XR_u));
                r_moon2 = (GM*R^4)./(GE*X_moon_n.^3).*(H2.*XR_u.*(1.5*Vmoon.^2 - 0.5) + 3*L2*Vmoon.*(X_moon_u - Vmoon.*XR_u));
                r = r_sun2 + r_moon2;
                
                %nominal degree 3 Love number
                H3 = 0.292;
                %nominal degree 3 Shida number
                L3 = 0.015;
                
                %solid Earth tide displacement (degree 3)
                r_sun3  = (GS.*R^5)./(GE.*X_sun_n.^4) .*(H3*XR_u.*(2.5.*Vsun.^3  - 1.5.*Vsun)  +   L3*(7.5*Vsun.^2  - 1.5).*(X_sun_u  - Vsun .*XR_u));
                r_moon3 = (GM.*R^5)./(GE.*X_moon_n.^4).*(H3*XR_u.*(2.5.*Vmoon.^3 - 1.5.*Vmoon) +   L3*(7.5*Vmoon.^2 - 1.5).*(X_moon_u - Vmoon.*XR_u));
                r = r + r_sun3 + r_moon3;
                
                %from "conventional tide free" to "mean tide"
                radial = (-0.1206 + 0.0001*p)*p;
                north  = (-0.0252 + 0.0001*p)*sin(2*phiC);
                r = r + repmat([radial*c + north*b]',time.length,1);
                
                %displacement along the receiver-satellite line-of-sight
                
                LOS  = XR - XS;
                LOSu = rowNormalize(LOS);
                solid_earth_corr = zeros(size(idx_sat));
                solid_earth_corr(idx_sat) = sum(conj(r).*LOSu,2);
            end
        end
        function [ocean_load_dcorr] = computeOceanLoading()
            
            % SYNTAX:
            %   [oceanloadcorr] = ocean_loading_correction(time, XR, XS);
            %
            % INPUT:
            %
            % OUTPUT:
            %   oceanloadcorr = ocean loading correction terms (along the satellite-receiver line-of-sight)
            %
            % DESCRIPTION:
            %   Computation of the ocean loading displacement terms.
            
            %ocean loading displacements matrix, station-dependent (see http://holt.oso.chalmers.se/loading/)
            global ol_disp zero_time
            
            ocean_load_dcorr = zeros(size(XS,1),1);
            if (isempty(ol_disp))
                return
            end
            
            %terms depending on the longitude of the lunar node (see Kouba and Heroux, 2001)
            fj = 1; %(at 1-3 mm precision)
            uj = 0; %(at 1-3 mm precision)
            
            %ref: http://202.127.29.4/cddisa/data_base/IERS/Convensions/Convension_2003/SUBROUTINES/ARG.f
            tidal_waves = [1.40519E-4, 2.0,-2.0, 0.0, 0.00; ... % M2  - semidiurnal
                1.45444E-4, 0.0, 0.0, 0.0, 0.00; ... % S2  - semidiurnal
                1.37880E-4, 2.0,-3.0, 1.0, 0.00; ... % N2  - semidiurnal
                1.45842E-4, 2.0, 0.0, 0.0, 0.00; ... % K2  - semidiurnal
                0.72921E-4, 1.0, 0.0, 0.0, 0.25; ... % K1  - diurnal
                0.67598E-4, 1.0,-2.0, 0.0,-0.25; ... % O1  - diurnal
                0.72523E-4,-1.0, 0.0, 0.0,-0.25; ... % P1  - diurnal
                0.64959E-4, 1.0,-3.0, 1.0,-0.25; ... % Q1  - diurnal
                0.53234E-5, 0.0, 2.0, 0.0, 0.00; ... % Mf  - long-period
                0.26392E-5, 0.0, 1.0,-1.0, 0.00; ... % Mm  - long-period
                0.03982E-5, 2.0, 0.0, 0.0, 0.00];    % Ssa - long-period
            
            refdate = datenum([1975 1 1 0 0 0]);
            
            [week, sow] = time2weektow(zero_time + time);
            dateUTC = datevec(gps2utc(datenum(gps2date(week, sow))));
            
            %separate the fractional part of day in seconds
            fday = dateUTC(4)*3600 + dateUTC(5)*60 + dateUTC(6);
            dateUTC(4:end) = 0;
            
            %number of days since reference date (1 Jan 1975)
            days = (datenum(dateUTC) - refdate);
            
            capt = (27392.500528 + 1.000000035*days)/36525;
            
            %mean longitude of the Sun at the beginning of day
            H0 = (279.69668 + (36000.768930485 + 3.03e-4*capt)*capt)*pi/180;
            
            %mean longitude of the Moon at the beginning of day
            S0 = (((1.9e-6*capt - 0.001133)*capt + 481267.88314137)*capt + 270.434358)*pi/180;
            
            %mean longitude of the lunar perigee at the beginning of day
            P0 = (((-1.2e-5*capt - 0.010325)*capt + 4069.0340329577)*capt + 334.329653)*pi/180;
            
            corr = zeros(3,1);
            for k = 1 : 11
                angle = tidal_waves(k,1)*fday + tidal_waves(k,2)*H0 + tidal_waves(k,3)*S0 + tidal_waves(k,4)*P0 + tidal_waves(k,5)*2*pi;
                corr  = corr + fj*ol_disp(1).matrix(1:3,k).*cos(angle + uj - ol_disp(1).matrix(4:6,k)*pi/180);
            end
            corrENU(1,1) = -corr(2,1); %east
            corrENU(2,1) = -corr(3,1); %north
            corrENU(3,1) =  corr(1,1); %up
            
            %displacement along the receiver-satellite line-of-sight
            XRcorr = local2globalPos(corrENU, XR);
            corrXYZ = XRcorr - XR;
            for s = 1 : size(XS,1)
                LOS  = XR - XS(s,:)';
                LOSu = LOS / norm(LOS);
                % oceanloadcorr(s,1) = dot(corrXYZ,LOSu);
                ocean_load_dcorr(s,1) = sum(conj(corrXYZ).*LOSu);
            end
        end
            function [poletidecorr] = getPoleTideCorr(this, time, XR, XS, phiC, lam)
                
                % SYNTAX:
                %   [poletidecorr] = pole_tide_correction(time, XR, XS, SP3, phiC, lam);
                %
                % INPUT:
                %   time = GPS time
                %   XR   = receiver position  (X,Y,Z)
                %   XS   = satellite position (X,Y,Z)
                %   phiC = receiver geocentric latitude (rad)
                %   lam  = receiver longitude (rad)
                %
                % OUTPUT:
                %   poletidecorr = pole tide correction terms (along the satellite-receiver line-of-sight)
                %
                % DESCRIPTION:
                %   Computation of the pole tide displacement terms.
                if (nargin < 5)
                    [~, lam, ~, phiC] = cart2geod(XR(1,1), XR(2,1), XR(3,1));
                end
                
                poletidecorr = zeros(size(XS,1),1);
                
                %interpolate the pole displacements
                if (~isempty(this.ERP))
                    if (length(this.ERP.t) > 1)
                        m1 = interp1(this.ERP.t, this.ERP.m1, time, 'linear', 'extrap');
                        m2 = interp1(this.ERP.t, this.ERP.m2, time, 'linear', 'extrap');
                    else
                        m1 = this.ERP.m1;
                        m2 = this.ERP.m2;
                    end
                    
                    deltaR   = -33*sin(2*phiC)*(m1*cos(lam) + m2*sin(lam))*1e-3;
                    deltaLam =  9* cos(  phiC)*(m1*sin(lam) - m2*cos(lam))*1e-3;
                    deltaPhi = -9* cos(2*phiC)*(m1*cos(lam) + m2*sin(lam))*1e-3;
                    
                    corrENU(1,1) = deltaLam; %east
                    corrENU(2,1) = deltaPhi; %north
                    corrENU(3,1) = deltaR;   %up
                    
                    %displacement along the receiver-satellite line-of-sight
                    XRcorr = local2globalPos(corrENU, XR);
                    corrXYZ = XRcorr - XR;
                    for s = 1 : size(XS,1)
                        LOS  = XR - XS(s,:)';
                        LOSu = LOS / norm(LOS);
                        poletidecorr(s,1) = -dot(corrXYZ,LOSu);
                    end
                end
                
            end
            function updateAzimuthElevation(this, XS, XR)
            end
            function [az, el] = getAzimuthElevation(this, XS, XR)
                % SYNTAX:
                %   [az, el] = this.getAzimuthElevation(XS)
                %
                % INPUT:
                % XS = positions of satellite [n_epoch x 1]
                % XR = positions of reciever [n_epoch x 1] (optional, non static
                % case)
                % OUTPUT:
                % Az = Azimuths of satellite [n_epoch x 1]
                % El = Elevations of satellite [n_epoch x 1]
                % during time of travel
                % DESCRIPTION:
                %   Compute Azimuth and elevation of the staellite
                n_epoch = size(XS,1);
                if nargin > 2
                    if size(XR,1) ~= n_epoch
                        this.logger.addError('[ getAzimuthElevation ] Number of satellite positions differ from number of receiver positions');
                        return
                    end
                else
                    XR = repmat(this.xyz(1,:),n_epoch,1);
                end
                
                az = zeros(n_epoch,1); el = zeros(n_epoch,1);
                
                [phi, lam] = cart2geod(XR(:,1), XR(:,2), XR(:,3));
                XSR = XS - XR; %%% sats orbit with origon in receiver
                
                e_unit = [-sin(lam)            cos(lam)           zeros(size(lam))       ]; % East unit vector
                n_unit = [-sin(phi).*cos(lam) -sin(phi).*sin(lam) cos(phi)]; % North unit vector
                u_unit = [ cos(phi).*cos(lam)  cos(phi).*sin(lam) sin(phi)]; % Up unit vector
                
                e = sum(e_unit .* XSR,2);
                n = sum(n_unit .* XSR,2);
                u = sum(u_unit .* XSR,2);
                
                hor_dist = sqrt( e.^2 + n.^2);
                
                zero_idx = hor_dist < 1.e-20;
                
                az(zero_idx) = 0;
                el(zero_idx) = 90;
                
                az(~zero_idx) = atan2d(e(~zero_idx),n(~zero_idx));
                el(~zero_idx) = atan2d(u(~zero_idx),hor_dist(~zero_idx));
                
                
            end
            function [dist, corr] = getRelDistance(this, XS, XR)
                % SYNTAX:
                %   [corr, distSR_corr] = this.getRelDistance(XS, XR);
                %
                % INPUT:
                % XS = positions of satellite [n_epoch x 1]
                % XR = positions of reciever [n_epoch x 1] (optional, non static
                % case)
                %
                % OUTPUT:
                %   corr = relativistic range error correction term (Shapiro delay)
                %   dist = dist
                % DESCRIPTION:
                %   Compute distance from satellite ot reciever considering
                %   (Shapiro delay) - copied from
                %   relativistic_range_error_correction.m
                n_epoch = size(XS,1);
                if nargin > 2
                    if size(XR,1) ~= n_epoch
                        this.log.addError('[ getRelDistance ] Number of satellite positions differ from number of receiver positions');
                        return
                    end
                else
                    XR = repmat(this.xyz(1,:),n_epoch,1);
                end
                
                distR = sqrt(sum(XR.^2 ,2));
                distS = sqrt(sum(XS.^2 ,2));
                
                distSR = sqrt(sum((XS-XR).^2 ,2));
                
                
                GM = 3.986005e14;
                
                
                corr = 2*GM/(goGNSS.V_LIGHT^2)*log((distR + distS + distSR)./(distR + distS - distSR));
                
                dist = distSR + corr;
                
            end
        end
        
        methods (Access = private)
            function parseRin2Data(this, txt, lim, eoh)
                % Parse the data part of a RINEX 2 file -  the header must already be parsed
                % SYNTAX: this.parseRin2Data(txt, lim, eoh)
                
                % find all the observation lines
                t_line = find([false(eoh, 1); (txt(lim(eoh+1:end,1) + 2) ~= ' ')' & (txt(lim(eoh+1:end,1) + 3) == ' ')' & lim(eoh+1:end,3) > 25]);
                n_epo = numel(t_line);
                % extract all the epoch lines
                string_time = txt(repmat(lim(t_line,1),1,25) + repmat(1:25, n_epo, 1))';
                % convert the times into a 6 col time
                date = cell2mat(textscan(string_time,'%2f %2f %2f %2f %2f %10.7f'));
                after_70 = (date(:,1) < 70); date(:, 1) = date(:, 1) + 1900 + after_70 * 100; % convert to 4 digits
                % import it as a GPS_Time obj
                this.time = GPS_Time(date, [], this.file.first_epoch.is_gps);
                this.rate = this.time.getRate();
                n_epo = numel(t_line);
                
                % get number of sat per epoch
                this.n_spe = sscanf(txt(repmat(lim(t_line,1),1,3) + repmat(29:31, n_epo, 1))', '%d');
                
                all_sat = [];
                for e = 1 : n_epo
                    n_sat = this.n_spe(e);
                    sat = serialize(txt(lim(t_line(e),1) + repmat((0 : ceil(this.n_spe(e) / 12) - 1)' * 69, 1, 36) + repmat(32:67, ceil(this.n_spe(e) / 12), 1))')';
                    sat = sat(1:n_sat * 3);
                    all_sat = [all_sat sat];
                end
                all_sat = reshape(all_sat, 3, numel(all_sat)/3)';
                
                gps_prn = unique(sscanf(all_sat(all_sat(:,1) == 'G', 2 : 3)', '%2d'));
                glo_prn = unique(sscanf(all_sat(all_sat(:,1) == 'R', 2 : 3)', '%2d'));
                gal_prn = unique(sscanf(all_sat(all_sat(:,1) == 'E', 2 : 3)', '%2d'));
                qzs_prn = unique(sscanf(all_sat(all_sat(:,1) == 'J', 2 : 3)', '%2d'));
                bds_prn = unique(sscanf(all_sat(all_sat(:,1) == 'C', 2 : 3)', '%2d'));
                irn_prn = unique(sscanf(all_sat(all_sat(:,1) == 'I', 2 : 3)', '%2d'));
                sbs_prn = unique(sscanf(all_sat(all_sat(:,1) == 'S', 2 : 3)', '%2d'));
                prn = struct('g', gps_prn', 'r', glo_prn', 'e', gal_prn', 'j', qzs_prn', 'c', bds_prn', 'i', irn_prn', 's', sbs_prn');
                
                % update the maximum number of rows to store
                n_obs = numel(prn.g) * numel(this.rin_obs_code.g) / 3 + ...
                    numel(prn.r) * numel(this.rin_obs_code.r) / 3 + ...
                    numel(prn.e) * numel(this.rin_obs_code.e) / 3 + ...
                    numel(prn.j) * numel(this.rin_obs_code.j) / 3 + ...
                    numel(prn.c) * numel(this.rin_obs_code.c) / 3 + ...
                    numel(prn.i) * numel(this.rin_obs_code.i) / 3 + ...
                    numel(prn.s) * numel(this.rin_obs_code.s) / 3;
                
                clear gps_prn glo_prn gal_prn qzs_prn bds_prn irn_prn sbs_prn;
                
                % order of storage
                % sat_system / obs_code / satellite
                sys_c = char(this.cc.sys_c + 32);
                n_ss = numel(sys_c); % number of satellite system
                
                % init datasets
                obs = zeros(n_obs, n_epo);
                
                this.obs_code = [];
                this.prn = [];
                this.system = [];
                this.f_id = [];
                this.wl = [];
                
                for  s = 1 : n_ss
                    sys = sys_c(s);
                    n_sat = numel(prn.(sys)); % number of satellite system
                    this.n_sat = this.n_sat + n_sat;
                    n_code = numel(this.rin_obs_code.(sys)) / 3; % number of satellite system
                    % transform in n_code x 3
                    obs_code = reshape(this.rin_obs_code.(sys), 3, n_code)';
                    % replicate obs_code for n_sat
                    obs_code = serialize(repmat(obs_code, 1, n_sat)');
                    obs_code = reshape(obs_code, 3, numel(obs_code) / 3)';
                    
                    this.obs_code = [this.obs_code; obs_code];
                    prn_ss = repmat(prn.(sys)', n_code, 1);
                    this.prn = [this.prn; prn_ss];
                    this.system = [this.system repmat(char(sys - 32), 1, size(obs_code, 1))];
                    
                    f_id = obs_code(:,2);
                    ss = this.cc.(char((this.cc.SYS_NAME{s} + 32)));
                    [~, f_id] = ismember(f_id, ss.CODE_RIN3_2BAND);
                    
                    ismember(this.system, this.cc.SYS_C);
                    this.f_id = [this.f_id; f_id];
                    
                    if s == 2
                        wl = ss.L_VEC((max(1, f_id) - 1) * size(ss.L_VEC, 1) + ss.PRN2IDCH(min(prn_ss, ss.N_SAT))');
                        wl(prn_ss > ss.N_SAT) = NaN;
                        wl(f_id == 0) = NaN;
                    else
                        wl = ss.L_VEC(max(1, f_id))';
                        wl(f_id == 0) = NaN;
                    end
                    this.wl = [this.wl; wl];
                end
                
                this.w_bar.createNewBar(' Parsing epochs...');
                this.w_bar.setBarLen(n_epo);
                
                n_ops = numel(this.rin_obs_code.g)/3; % number of observations per satellite
                n_lps = ceil(n_ops / 5); % number of obbservation lines per satellite
                
                mask = repmat('         0.00000',1 ,40);
                data_pos = repmat(logical([true(1, 14) false(1, 2)]),1 ,40);
                id_line  = reshape(1 : numel(mask), 80, numel(mask)/80);
                for e = 1 : n_epo % for each epoch
                    n_sat = this.n_spe(e);
                    sat = serialize(txt(lim(t_line(e),1) + repmat((0 : ceil(this.n_spe(e) / 12) - 1)' * 69, 1, 36) + repmat(32:67, ceil(this.n_spe(e) / 12), 1))')';
                    sat = sat(~isspace(sat));
                    sat = sat(1:n_sat * 3);
                    sat = reshape(sat, 3, n_sat)';
                    prn_e = sscanf(serialize(sat(:,2:3)'), '%02d');
                    for s = 1 : size(sat, 1)
                        % line to fill with the current observation line
                        obs_line = (this.prn == prn_e(s)) & this.system' == sat(s, 1);
                        line_start = t_line(e) + ceil(n_sat / 12) + (s-1) * n_lps;
                        line = mask(1 : n_ops * 16);
                        for i = 0 : n_lps - 1
                            try
                                line(id_line(1:lim(line_start + i, 3),i+1)) = txt(lim(line_start + i, 1) : lim(line_start + i, 2)-1);
                            catch
                                % empty last lines
                            end
                        end
                        % remove return characters
                        ck = line == ' '; line(ck) = mask(ck); % fill empty fields -> otherwise textscan ignore the empty fields
                        % try with sscanf
                        line = line(data_pos(1 : numel(line)));
                        data = sscanf(reshape(line, 14, numel(line) / 14), '%f');
                        obs(obs_line, e) = data;
                        % alternative approach with textscan
                        %data = textscan(line, '%14.3f%1d%1d');
                        %obs(obs_line(1:numel(data{1})), e) = data{1};
                    end
                    this.w_bar.go(e);
                end
                this.logger.newLine();
                this.obs = obs;
            end
            
            function parseRin3Data(this, txt, lim, eoh)
                % find all the observation lines
                t_line = find([false(eoh, 1); (txt(lim(eoh+1:end,1)) == '>')']);
                n_epo = numel(t_line);
                % extract all the epoch lines
                string_time = txt(repmat(lim(t_line,1),1,27) + repmat(2:28, n_epo, 1))';
                % convert the times into a 6 col time
                date = cell2mat(textscan(string_time,'%4f %2f %2f %2f %2f %10.7f'));
                % import it as a GPS_Time obj
                this.time = GPS_Time(date, [], this.file.first_epoch.is_gps);
                this.rate = this.time.getRate();
                n_epo = numel(t_line);
                
                % get number of observations per epoch
                this.n_spe = sscanf(txt(repmat(lim(t_line,1),1,3) + repmat(32:34, n_epo, 1))', '%d');
                d_line = find(~[true(eoh, 1); (txt(lim(eoh+1:end,1)) == '>')']);
                
                all_sat = txt(repmat(lim(d_line,1), 1, 3) + repmat(0 : 2, numel(d_line), 1));
                
                % find the data present into the file
                gps_line = d_line(txt(lim(d_line,1)) == 'G');
                glo_line = d_line(txt(lim(d_line,1)) == 'R');
                gal_line = d_line(txt(lim(d_line,1)) == 'E');
                qzs_line = d_line(txt(lim(d_line,1)) == 'J');
                bds_line = d_line(txt(lim(d_line,1)) == 'C');
                irn_line = d_line(txt(lim(d_line,1)) == 'I');
                sbs_line = d_line(txt(lim(d_line,1)) == 'S');
                % Activate only the constellation that are present in the receiver
                %this.cc.setActive([isempty(gps_line) isempty(glo_line) isempty(gal_line) isempty(qzs_line) isempty(bds_line) isempty(irn_line) isempty(sbs_line)]);
                
                gps_prn = unique(sscanf(txt(repmat(lim(gps_line,1), 1, 2) + repmat(1 : 2, numel(gps_line), 1))', '%2d'));
                glo_prn = unique(sscanf(txt(repmat(lim(glo_line,1), 1, 2) + repmat(1 : 2, numel(glo_line), 1))', '%2d'));
                gal_prn = unique(sscanf(txt(repmat(lim(gal_line,1), 1, 2) + repmat(1 : 2, numel(gal_line), 1))', '%2d'));
                qzs_prn = unique(sscanf(txt(repmat(lim(qzs_line,1), 1, 2) + repmat(1 : 2, numel(qzs_line), 1))', '%2d'));
                bds_prn = unique(sscanf(txt(repmat(lim(bds_line,1), 1, 2) + repmat(1 : 2, numel(bds_line), 1))', '%2d'));
                irn_prn = unique(sscanf(txt(repmat(lim(irn_line,1), 1, 2) + repmat(1 : 2, numel(irn_line), 1))', '%2d'));
                sbs_prn = unique(sscanf(txt(repmat(lim(sbs_line,1), 1, 2) + repmat(1 : 2, numel(sbs_line), 1))', '%2d'));
                prn = struct('g', gps_prn', 'r', glo_prn', 'e', gal_prn', 'j', qzs_prn', 'c', bds_prn', 'i', irn_prn', 's', sbs_prn');
                
                % update the maximum number of rows to store
                n_obs = this.cc.gps.isActive * numel(prn.g) * numel(this.rin_obs_code.g) / 3 + ...
                    this.cc.glo.isActive * numel(prn.r) * numel(this.rin_obs_code.r) / 3 + ...
                    this.cc.gal.isActive * numel(prn.e) * numel(this.rin_obs_code.e) / 3 + ...
                    this.cc.qzs.isActive * numel(prn.j) * numel(this.rin_obs_code.j) / 3 + ...
                    this.cc.bds.isActive * numel(prn.c) * numel(this.rin_obs_code.c) / 3 + ...
                    this.cc.irn.isActive * numel(prn.i) * numel(this.rin_obs_code.i) / 3 + ...
                    this.cc.sbs.isActive * numel(prn.s) * numel(this.rin_obs_code.s) / 3;
                
                clear gps_prn glo_prn gal_prn qzs_prn bds_prn irn_prn sbs_prn;
                
                % order of storage
                % sat_system / obs_code / satellite
                sys_c = char(this.cc.sys_c + 32);
                n_ss = numel(sys_c); % number of satellite system
                
                % init datasets
                obs = zeros(n_obs, n_epo);
                
                this.obs_code = [];
                this.prn = [];
                this.system = [];
                this.f_id = [];
                this.wl = [];
                this.n_sat = 0;
                for  s = 1 : n_ss
                    sys = sys_c(s);
                    n_sat = numel(prn.(sys)); % number of satellite system
                    this.n_sat = this.n_sat + n_sat;
                    n_code = numel(this.rin_obs_code.(sys)) / 3; % number of satellite system
                    % transform in n_code x 3
                    obs_code = reshape(this.rin_obs_code.(sys), 3, n_code)';
                    % replicate obs_code for n_sat
                    obs_code = serialize(repmat(obs_code, 1, n_sat)');
                    obs_code = reshape(obs_code, 3, numel(obs_code) / 3)';
                    
                    this.obs_code = [this.obs_code; obs_code];
                    prn_ss = repmat(prn.(sys)', n_code, 1);
                    this.prn = [this.prn; prn_ss];
                    this.system = [this.system repmat(char(sys - 32), 1, size(obs_code, 1))];
                    
                    f_id = obs_code(:,2);
                    ss = this.cc.(char((this.cc.SYS_NAME{s} + 32)));
                    [~, f_id] = ismember(f_id, ss.CODE_RIN3_2BAND);
                    
                    ismember(this.system, this.cc.SYS_C);
                    this.f_id = [this.f_id; f_id];
                    
                    if s == 2
                        wl = ss.L_VEC((max(1, f_id) - 1) * size(ss.L_VEC, 1) + ss.PRN2IDCH(min(prn_ss, ss.N_SAT))');
                        wl(prn_ss > ss.N_SAT) = NaN;
                        wl(f_id == 0) = NaN;
                    else
                        wl = ss.L_VEC(max(1, f_id))';
                        wl(f_id == 0) = NaN;
                    end
                    if sum(f_id == 0)
                        [~, id] = unique(double(obs_code(f_id == 0, :)) * [1 10 100]');
                        this.logger.addWarning(sprintf('These codes for the %s are not recognized, ignoring data: %s', ss.SYS_EXT_NAME, sprintf('%c%c%c ', obs_code(id, :)')));
                    end
                    this.wl = [this.wl; wl];
                end
                
                this.w_bar.createNewBar(' Parsing epochs...');
                this.w_bar.setBarLen(n_epo);
                
                mask = repmat('         0.00000',1 ,40);
                data_pos = repmat(logical([true(1, 14) false(1, 2)]),1 ,40);
                for e = 1 : n_epo % for each epoch
                    sat = txt(repmat(lim(t_line(e) + 1 : t_line(e) + this.n_spe(e),1),1,3) + repmat(0:2, this.n_spe(e), 1));
                    prn_e = sscanf(serialize(sat(:,2:3)'), '%02d');
                    for s = 1 : size(sat, 1)
                        % line to fill with the current observation line
                        obs_line = find((this.prn == prn_e(s)) & this.system' == sat(s, 1));
                        if ~isempty(obs_line)
                            line = txt(lim(t_line(e) + s, 1) + 3 : lim(t_line(e) + s, 2));
                            ck = line == ' '; line(ck) = mask(ck); % fill empty fields -> otherwise textscan ignore the empty fields
                            % try with sscanf
                            line = line(data_pos(1 : numel(line)));
                            data = sscanf(reshape(line, 14, numel(line) / 14), '%f');
                            obs(obs_line(1:size(data,1)), e) = data;
                        end
                        % alternative approach with textscan
                        %data = textscan(line, '%14.3f%1d%1d');
                        %obs(obs_line(1:numel(data{1})), e) = data{1};
                    end
                    this.w_bar.go(e);
                end
                this.logger.newLine();
                this.obs = obs;
                
            end
        end
        
    end
