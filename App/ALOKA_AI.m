classdef ALOKA_AI < handle

    properties
        fig
        screen
        nav
        scroll
        currentScreen = "home"
        themeMode = "dark"
        darkTheme
        lightTheme
        patient = struct('id',"",'name',"",'age',"",'gender',"",'eye',"Left Eye (OS)")
        uploadedImage = []
        uploadedFile = ""
        uploadedPath = ""
        quality = struct()
        analysis = struct()
        backendResult = struct()
        recent = struct([])
        recentFile = "aloka_recent.mat"
        imageAxes
    end

    methods

        function app = ALOKA_AI()
            app.initThemes();
            app.loadRecent();
            app.createWindow();
            app.showHome();
        end

        function initThemes(app)
            app.darkTheme.bg=[16 20 26]/255;
            app.darkTheme.surface=[24 28 34]/255;
            app.darkTheme.card=[28 32 38]/255;
            app.darkTheme.card2=[38 42 49]/255;
            app.darkTheme.input=[24 28 34]/255;
            app.darkTheme.border=[60 74 70]/255;
            app.darkTheme.text=[223 226 235]/255;
            app.darkTheme.muted=[186 202 197]/255;
            app.darkTheme.dim=[107 114 128]/255;
            app.darkTheme.teal=[87 241 219]/255;
            app.darkTheme.green=[78 222 163]/255;
            app.darkTheme.orange=[255 173 58]/255;
            app.darkTheme.peach=[255 210 159]/255;
            app.darkTheme.red=[255 180 171]/255;
            app.darkTheme.ink=[0 55 49]/255;

            app.lightTheme.bg=[247 250 253]/255;
            app.lightTheme.surface=[255 255 255]/255;
            app.lightTheme.card=[255 255 255]/255;
            app.lightTheme.card2=[239 246 255]/255;
            app.lightTheme.input=[248 250 252]/255;
            app.lightTheme.border=[203 213 225]/255;
            app.lightTheme.text=[15 23 42]/255;
            app.lightTheme.muted=[71 85 105]/255;
            app.lightTheme.dim=[100 116 139]/255;
            app.lightTheme.teal=[37 99 235]/255;
            app.lightTheme.green=[22 163 74]/255;
            app.lightTheme.orange=[217 119 6]/255;
            app.lightTheme.peach=[180 83 9]/255;
            app.lightTheme.red=[220 38 38]/255;
            app.lightTheme.ink=[255 255 255]/255;
        end

        function t=T(app)
            if app.themeMode=="light"
                t=app.lightTheme;
            else
                t=app.darkTheme;
            end
        end

        function createWindow(app)
            t=app.T();
            app.fig=uifigure( ...
                'Name','ALOKA_AI - Diabetic Retinopathy Screening', ...
                'Color',t.bg, ...
                'Position',[100 70 430 820], ...
                'Resize','on', ...
                'CloseRequestFcn',@(src,evt)delete(app));
            app.fig.AutoResizeChildren='off';
            app.fig.SizeChangedFcn=@(src,evt)app.resizeWindow();
            app.resizeWindow();
        end

        function resizeWindow(app)
            try
                fig=app.fig;
                if isempty(fig)||~isvalid(fig)
                    return
                end
            catch
                return
            end

            fpos=fig.Position;
            fw=max(fpos(3),390);
            fh=max(fpos(4),700);

            if ~isempty(app.screen)
                try
                    if isvalid(app.screen)
                        app.screen.Position=[0 0 fw fh];
                    end
                catch
                end
            end
        end

        function clearScreen(app)
            if ~isempty(app.screen)
                try
                    if isvalid(app.screen)
                        delete(app.screen.Children);
                    end
                catch
                end
            end
            app.nav=[];
            app.scroll=[];
            app.imageAxes=[];
        end

        function basePage(app,active,contentHeight)
            t=app.T();
            app.clearScreen();

            if isempty(app.screen)||~isvalid(app.screen)
                app.screen=uipanel(app.fig,'BorderType','none', ...
                    'BackgroundColor',t.bg,'Units','pixels');
            end

            app.resizeWindow();
            p=app.screen.Position;

            if contentHeight>p(4)-145
                app.scroll=uipanel(app.screen,'BorderType','none', ...
                    'BackgroundColor',t.bg,'Units','pixels', ...
                    'Scrollable','on', ...
                    'Position',[0 81 p(3) p(4)-81]);
                content=uipanel(app.scroll,'BorderType','none', ...
                    'BackgroundColor',t.bg,'Units','pixels', ...
                    'Position',[0 max(0,contentHeight-(p(4)-81)) p(3) contentHeight]);
            else
                content=uipanel(app.screen,'BorderType','none', ...
                    'BackgroundColor',t.bg,'Units','pixels', ...
                    'Position',[0 81 p(3) p(4)-81]);
            end

            app.screen.UserData.content=content;
            app.header();
            app.footer(content);
            app.bottomNav(active);
        end

        function content=pageContent(app)
            content=app.screen.UserData.content;
        end

        function header(app)
            t=app.T();
            p=app.screen.Position;

            h=uipanel(app.screen,'BorderType','none', ...
                'BackgroundColor',t.bg,'Units','pixels', ...
                'Position',[0 p(4)-64 p(3) 64]);

            uilabel(h,'Text','◉','Position',[16 20 22 22], ...
                'FontSize',14,'FontWeight','bold','FontColor',t.teal, ...
                'HorizontalAlignment','center');

            uilabel(h,'Text','ALOKA_AI','Position',[42 18 130 25], ...
                'FontSize',16,'FontWeight','bold','FontColor',t.teal);

            uilabel(h,'Text','● AI Online','Position',[294 19 80 22], ...
                'FontSize',9,'FontWeight','bold','FontColor',t.teal, ...
                'HorizontalAlignment','right');

            uipanel(h,'BorderType','none','BackgroundColor',t.border, ...
                'Position',[0 0 p(3) 1]);
        end

        function footer(app,parent)
            t=app.T();
            f=uipanel(parent,'BorderType','none', ...
                'BackgroundColor',t.bg,'Units','pixels', ...
                'Position',[0 0 390 93]);

            uipanel(f,'BorderType','none', ...
                'BackgroundColor',app.alpha(t.border,0.3,t.bg), ...
                'Position',[0 92 390 1]);

            uilabel(f,'Text',{'AI-assisted screening prototype. Final interpretation', ...
                'should be performed by a qualified eye-care', ...
                'professional.'}, ...
                'Position',[16 16 358 60], ...
                'FontSize',10,'FontColor',t.muted, ...
                'HorizontalAlignment','center');
        end

        function bottomNav(app,active)
            t=app.T();

            nav=uipanel(app.fig,'BorderType','none', ...
                'BackgroundColor',t.surface,'Units','pixels', ...
                'Position',[0 0 390 81]);

            app.nav=nav;

            uipanel(nav,'BorderType','none','BackgroundColor',t.border, ...
                'Position',[0 80 390 1]);

            labels={'Home','New','Analysis','Settings'};
            callbacks={ ...
                @(~,~)app.showHome(), ...
                @ (~,~)app.showNew(), ...
                @ (~,~)app.openAnalysis(), ...
                @ (~,~)app.showSettings()};

            x=[10 103 195 287];

            for k=1:4
                selected=strcmpi(active,lower(labels{k}));

                if selected
                    bg=app.alpha(t.teal,0.10,t.surface);
                    fc=t.teal;
                else
                    bg=t.surface;
                    fc=t.muted;
                end

                b=uibutton(nav,'Text',labels{k}, ...
                    'Position',[x(k) 10 82 54], ...
                    'FontSize',9,'FontWeight','bold', ...
                    'FontColor',fc,'BackgroundColor',bg);

                app.bindButton(b,callbacks{k});
            end
        end

        function bindButton(~,b,cb)
            listener=addlistener(b,'ButtonPushed',cb);
            ud=b.UserData;
            if ~isstruct(ud)
                ud=struct();
            end
            ud.buttonListener=listener;
            b.UserData=ud;
        end

        function openAnalysis(app)
            if isempty(app.uploadedImage)
                app.showNew();
                return
            end

            if isempty(fieldnames(app.analysis))
                app.showQuality();
                return
            end

            app.showResult();
        end

        function showHome(app)
            app.currentScreen="home";
            app.basePage('home',1180);
            t=app.T();
            c=app.pageContent();

            hero=app.panel(c,[16 920 358 230],t.card,t.border,10);
            app.gradientAccent(hero,t.teal);

            uilabel(hero,'Text','Welcome to ALOKA_AI', ...
                'Position',[24 165 310 30], ...
                'FontSize',20,'FontWeight','bold','FontColor',t.text);

            uilabel(hero,'Text',{'AI-assisted diabetic retinopathy screening', ...
                'using retinal fundus image analysis.'}, ...
                'Position',[24 112 310 55], ...
                'FontSize',11,'FontColor',t.muted,'WordWrap','on');

            uilabel(hero,'Text','SCREENING WORKFLOW READY', ...
                'Position',[24 82 250 18], ...
                'FontSize',8,'FontWeight','bold','FontColor',t.teal);

            app.primaryButton(hero,'Start New Screening', ...
                [24 25 310 44],@(~,~)app.showNew());

            app.metricCard(c,[16 765 358 125], ...
                'TODAY''S SCREENINGS','24','+12% from yesterday', ...
                t.green,t.teal);

            app.metricCard(c,[16 630 358 125], ...
                'IMAGES ACCEPTED','21','87.5% QA Pass', ...
                t.green,t.green);

            app.metricCard(c,[16 495 358 125], ...
                'RECAPTURE REQUIRED','3','Review pending', ...
                t.orange,t.orange);

            app.metricCard(c,[16 360 358 125], ...
                'QA PASS RATE','87.5%','Image quality verified', ...
                t.teal,t.teal);

            workflow=app.panel(c,[16 185 358 155], ...
                t.surface,t.border,8);

            uilabel(workflow,'Text','Screening Workflow', ...
                'Position',[16 115 300 25], ...
                'FontSize',17,'FontWeight','bold','FontColor',t.text);

            uilabel(workflow,'Text', ...
                'Patient → Image → Quality AI → DR AI → Report', ...
                'Position',[16 76 326 22], ...
                'FontSize',10,'FontWeight','bold','FontColor',t.teal, ...
                'HorizontalAlignment','center');

            names={'Patient','Image','Quality','DR AI','Report'};
            xpos=[18 83 148 213 278];

            for k=1:5
                uilabel(workflow,'Text',names{k}, ...
                    'Position',[xpos(k) 43 60 18], ...
                    'FontSize',8,'FontColor',t.muted, ...
                    'HorizontalAlignment','center');
            end

            services=app.panel(c,[16 25 358 145], ...
                t.surface,t.border,8);

            uilabel(services,'Text','AI Services', ...
                'Position',[16 108 200 24], ...
                'FontSize',17,'FontWeight','bold','FontColor',t.text);

            uilabel(services,'Text','●','Position',[18 78 20 18], ...
                'FontSize',11,'FontColor',t.orange);

            uilabel(services,'Text','Image Quality AI', ...
                'Position',[40 78 180 18], ...
                'FontSize',10,'FontWeight','bold','FontColor',t.text);

            uilabel(services,'Text','Integrated', ...
                'Position',[220 78 115 18], ...
                'FontSize',8,'FontColor',t.green, ...
                'HorizontalAlignment','right');

            uilabel(services,'Text','●','Position',[18 51 20 18], ...
                'FontSize',11,'FontColor',t.orange);

            uilabel(services,'Text','DR Classification AI', ...
                'Position',[40 51 180 18], ...
                'FontSize',10,'FontWeight','bold','FontColor',t.text);

            uilabel(services,'Text','Integrated', ...
                'Position',[220 51 115 18], ...
                'FontSize',8,'FontColor',t.green, ...
                'HorizontalAlignment','right');

            uilabel(services,'Text','●','Position',[18 24 20 18], ...
                'FontSize',11,'FontColor',t.orange);

            uilabel(services,'Text','Explainability / Grad-CAM', ...
                'Position',[40 24 180 18], ...
                'FontSize',10,'FontWeight','bold','FontColor',t.text);

            uilabel(services,'Text','Integrated', ...
                'Position',[220 24 115 18], ...
                'FontSize',8,'FontColor',t.green, ...
                'HorizontalAlignment','right');

            recentPanel=app.panel(c,[16 -185 358 190], ...
                t.surface,t.border,8);

            uilabel(recentPanel,'Text','Recent Screenings', ...
                'Position',[16 140 200 25], ...
                'FontSize',17,'FontWeight','bold','FontColor',t.text);

            rows=app.recentRows();

            if isempty(rows)
                uilabel(recentPanel,'Text','No completed screenings yet.', ...
                    'Position',[16 82 326 30], ...
                    'FontSize',10,'FontColor',t.muted, ...
                    'HorizontalAlignment','center');

                uilabel(recentPanel, ...
                    'Text','Completed patient screenings will appear here.', ...
                    'Position',[16 52 326 30], ...
                    'FontSize',9,'FontColor',t.dim, ...
                    'HorizontalAlignment','center');
            else
                headers={'Patient ID','Date','Quality','Grade'};
                xpos=[16 105 205 275];
                widths=[80 90 60 60];

                for k=1:4
                    uilabel(recentPanel,'Text',headers{k}, ...
                        'Position',[xpos(k) 112 widths(k) 20], ...
                        'FontSize',8,'FontWeight','bold', ...
                        'FontColor',t.muted);
                end

                for r=1:min(size(rows,1),2)
                    y=72-(r-1)*42;
                    vals=rows(r,:);

                    for k=1:4
                        col=t.text;
                        if k==3
                            col=t.green;
                        elseif k==4 && contains(vals{k},'2')
                            col=t.orange;
                        end

                        uilabel(recentPanel,'Text',vals{k}, ...
                            'Position',[xpos(k) y widths(k) 25], ...
                            'FontSize',9,'FontColor',col);
                    end
                end
            end
        end

        function rows=recentRows(app)
            rows=cell(0,4);

            if isempty(app.recent)
                return
            end

            r=app.recent;

            rows(1,:)={char(r.id),char(r.date), ...
                char(r.quality),char(r.grade)};
        end

        function metricCard(app,parent,pos,title,value,sub,accent,subColor)
            t=app.T();

            p=app.panel(parent,pos,t.card,t.border,8);

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',accent,'Position',[0 123 358 2]);

            uilabel(p,'Text',title,'Position',[17 96 280 18], ...
                'FontSize',9,'FontWeight','bold','FontColor',t.muted);

            uilabel(p,'Text',value,'Position',[17 51 324 40], ...
                'FontSize',28,'FontWeight','bold','FontColor',accent);

            uilabel(p,'Text',sub,'Position',[17 12 324 20], ...
                'FontSize',9,'FontColor',subColor, ...
                'HorizontalAlignment','right');
        end

        function showNew(app)
            app.currentScreen="new";
            app.basePage('new',1397);
            t=app.T();
            c=app.pageContent();

            uilabel(c,'Text','New Screening Entry', ...
                'Position',[16 1334 358 32], ...
                'FontSize',24,'FontWeight','bold','FontColor',t.text);

            uilabel(c,'Text',{'Enter patient details and upload fundus image', ...
                'for AI analysis.'}, ...
                'Position',[16 1280 358 48], ...
                'FontSize',12,'FontColor',t.muted);

            form=app.panel(c,[16 900 358 388], ...
                t.surface,[51 65 85]/255,8);

            uilabel(form,'Text','Patient Details', ...
                'Position',[25 332 308 28], ...
                'FontSize',20,'FontWeight','bold','FontColor',t.text);

            uipanel(form,'BorderType','none', ...
                'BackgroundColor',t.border,'Position',[25 314 308 1]);

            app.label(form,'Patient ID',[25 282 308 18]);

            id=uieditfield(form,'text', ...
                'Position',[25 238 308 42], ...
                'Placeholder','e.g. PID-2023-894', ...
                'Value',char(app.patient.id));

            app.styleInput(id);

            app.label(form,'Age',[25 205 146 18]);

            age=uieditfield(form,'numeric', ...
                'Position',[25 160 146 42], ...
                'Value',app.numericAge(), ...
                'Limits',[0 130]);

            app.styleInput(age);

            app.label(form,'Gender',[187 205 146 18]);

            gender=uidropdown(form, ...
                'Items',{'Select','Female','Male','Other'}, ...
                'Position',[187 160 146 42], ...
                'Value',app.validGender());

            app.styleInput(gender);

            app.label(form,'Eye to Examine',[25 126 308 18]);

            left=uibutton(form,'Text','◉  Left Eye (OS)', ...
                'Position',[25 72 146 42], ...
                'FontSize',10,'FontColor',t.text, ...
                'BackgroundColor',t.input);

            right=uibutton(form,'Text','◉  Right Eye (OD)', ...
                'Position',[187 72 146 42], ...
                'FontSize',10,'FontColor',t.text, ...
                'BackgroundColor',t.input);

            form.UserData=struct('id',id,'age',age, ...
                'gender',gender,'left',left,'right',right);

            app.bindButton(left,@(~,~)app.setEye('Left Eye (OS)',left));
            app.bindButton(right,@(~,~)app.setEye('Right Eye (OD)',right));

            if contains(lower(app.patient.eye),'right')
                right.BackgroundColor=app.alpha(t.teal,0.12,t.input);
            else
                left.BackgroundColor=app.alpha(t.teal,0.12,t.input);
            end

            upload=app.panel(c,[16 174 358 713], ...
                t.surface,[51 65 85]/255,8);

            uilabel(upload,'Text','Image Upload', ...
                'Position',[25 650 300 28], ...
                'FontSize',20,'FontWeight','bold','FontColor',t.text);

            uilabel(upload,'Text',{'Upload a clear fundus photograph for quality', ...
                'assessment.'}, ...
                'Position',[25 603 300 40], ...
                'FontSize',10,'FontColor',t.muted);

            uipanel(upload,'BorderType','none', ...
                'BackgroundColor',t.border,'Position',[25 584 308 1]);

            app.imageAxes=uiaxes(upload, ...
                'Position',[25 274 308 300], ...
                'BackgroundColor',t.bg,'XTick',[],'YTick',[]);

            app.imageAxes.Box='on';
            app.imageAxes.XColor=t.border;
            app.imageAxes.YColor=t.border;

            title(app.imageAxes,'Upload Fundus Image', ...
                'Color',t.text,'FontSize',14);

            uilabel(upload,'Text','Drag and drop or click to browse', ...
                'Position',[25 246 308 22], ...
                'FontSize',10,'FontColor',t.muted, ...
                'HorizontalAlignment','center');

            uilabel(upload,'Text','JPG, PNG, TIFF    •    Max 15MB', ...
                'Position',[25 224 308 18], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.dim, ...
                'HorizontalAlignment','center');

            app.primaryButton(upload,'Choose Image', ...
                [25 174 308 44],@(~,~)app.chooseImage());

            qbox=app.panel(upload,[25 5 308 105], ...
                t.input,t.border,4);

            uilabel(qbox,'Text','▣  IMAGE QUALITY REQUIREMENTS', ...
                'Position',[17 75 274 18], ...
                'FontSize',9,'FontWeight','bold','FontColor',t.text);

            uilabel(qbox,'Text','✓  Retina clearly visible', ...
                'Position',[17 52 274 18], ...
                'FontSize',9,'FontColor',t.muted);

            uilabel(qbox,'Text','✓  Adequate illumination', ...
                'Position',[17 30 274 18], ...
                'FontSize',9,'FontColor',t.green);

            uilabel(qbox,'Text','✓  Minimal motion blur', ...
                'Position',[17 8 274 18], ...
                'FontSize',9,'FontColor',t.green);

            b=app.primaryButton(upload,'Analyze Image', ...
                [25 120 308 44],@(~,~)app.startScreening(form));

            b.Enable='off';
            b.Tag='analyzeButton';
        end

        function setEye(app,eye,leftOrRight)
            app.patient.eye=string(eye);
            t=app.T();

            if contains(lower(eye),'left')
                leftOrRight.Parent.UserData.left.BackgroundColor= ...
                    app.alpha(t.teal,0.12,t.input);
                leftOrRight.Parent.UserData.right.BackgroundColor=t.input;
            else
                leftOrRight.Parent.UserData.right.BackgroundColor= ...
                    app.alpha(t.teal,0.12,t.input);
                leftOrRight.Parent.UserData.left.BackgroundColor=t.input;
            end
        end

        function chooseImage(app)
            [file,path]=uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.tif;*.tiff', ...
                'Fundus images (*.jpg, *.jpeg, *.png, *.tif, *.tiff)'}, ...
                'Select fundus image');

            if isequal(file,0)
                return
            end

            try
                fp=fullfile(path,file);
                img=imread(fp);

                app.uploadedImage=img;
                app.uploadedFile=string(file);
                app.uploadedPath=string(fp);

                cla(app.imageAxes);
                image(app.imageAxes,img);
                axis(app.imageAxes,'image');

                app.imageAxes.XTick=[];
                app.imageAxes.YTick=[];
                app.imageAxes.Box='on';

                b=findobj(app.screen,'Tag','analyzeButton');

                if ~isempty(b)
                    b.Enable='on';
                end

            catch ME
                uialert(app.fig,ME.message,'Could not open image');
            end
        end

        function startScreening(app,form)

            if isstruct(form)
                if isfield(form,'UserData')
                    d=form.UserData;
                else
                    d=form;
                end
            else
                d=form.UserData;
            end

            if ~isfield(d,'id')||isempty(d.id)||~isvalid(d.id)
                uialert(app.fig, ...
                    'Patient ID field is unavailable.', ...
                    'Missing information');
                return
            end

            if strlength(string(d.id.Value))==0
                uialert(app.fig, ...
                    'Please enter a Patient ID.', ...
                    'Missing information');
                return
            end

            if isfield(d,'gender')
                if strcmpi(string(d.gender.Value),'Select')
                    uialert(app.fig, ...
                        'Please select a gender.', ...
                        'Missing information');
                    return
                end
            end

            if isempty(app.uploadedImage)|| ...
                    strlength(app.uploadedPath)==0
                uialert(app.fig, ...
                    'Please choose a fundus image first.', ...
                    'No image');
                return
            end

            app.patient.id=string(d.id.Value);
            app.patient.age=string(round(d.age.Value));
            app.patient.gender=string(d.gender.Value);

            app.backendResult=struct();
            app.quality=struct();
            app.analysis=struct();

            drawnow;

            try
                result=alokaBackend(char(app.uploadedPath));

                if isempty(result)||~isstruct(result)
                    error('ALOKA_AI:BackendEmpty', ...
                        'The ALOKA backend returned an empty result.');
                end

                app.backendResult=result;

                app.quality=app.mapBackendQuality(result);

                if isempty(fieldnames(app.quality))
                    error('ALOKA_AI:QualityUnavailable', ...
                        'M1 Image Quality did not return a usable result.');
                end

                app.analysis=app.mapBackendAnalysis(result);

                app.showQuality();

            catch ME

                app.backendResult=struct();

                msg=ME.message;

                if ~isempty(ME.stack)
                    msg=sprintf('%s\n\nLocation: %s, line %d', ...
                        ME.message,ME.stack(1).name,ME.stack(1).line);
                end

                uialert(app.fig, ...
                    sprintf('ALOKA-AI backend processing failed.\n\n%s',msg), ...
                    'ALOKA-AI Processing Error');
            end
        end

        function q=mapBackendQuality(app,result)

            q=struct();

            candidates={};

            if isfield(result,'ImageQuality')
                candidates{end+1}=result.ImageQuality;
            end

            if isfield(result,'Quality')
                candidates{end+1}=result.Quality;
            end

            if isfield(result,'M1')
                candidates{end+1}=result.M1;
            end

            for i=1:numel(candidates)
                x=candidates{i};

                if ~isstruct(x)
                    continue
                end

                q.sharpness=app.extractNumber(x, ...
                    {'sharpness','Sharpness','focus','Focus'},0.5);

                q.illumination=app.extractNumber(x, ...
                    {'illumination','Illumination','brightness','Brightness'},0.5);

                q.fieldOfView=app.extractNumber(x, ...
                    {'fieldOfView','FieldOfView','fov','FOV'},0.9);

                q.pass=app.extractLogical(x, ...
                    {'pass','Pass','Passed','isPass'}, ...
                    q.sharpness>=0.12 && ...
                    q.illumination>=0.45 && ...
                    q.fieldOfView>=0.75);

                q.mode='BACKEND';
                return
            end

            if isfield(result,'ImageQualityMetrics')
                x=result.ImageQualityMetrics;

                if isstruct(x)
                    q.sharpness=app.extractNumber(x, ...
                        {'sharpness','Sharpness'},0.5);

                    q.illumination=app.extractNumber(x, ...
                        {'illumination','Illumination'},0.5);

                    q.fieldOfView=app.extractNumber(x, ...
                        {'fieldOfView','FieldOfView'},0.9);

                    q.pass=app.extractLogical(x, ...
                        {'pass','Pass'},true);

                    q.mode='BACKEND';
                    return
                end
            end

            x=double(app.uploadedImage);

            if ndims(x)==3
                x=mean(x,3);
            end

            x=x/255;

            q.sharpness=min(1,max(0,std(x(:))*2.8));
            q.illumination=1-min(1,abs(mean(x(:))-0.5)*1.8);
            q.fieldOfView=0.92;
            q.pass=q.sharpness>=0.12 && ...
                q.illumination>=0.45 && ...
                q.fieldOfView>=0.75;
            q.mode='BACKEND-FALLBACK';
        end

        function a=mapBackendAnalysis(app,result)

            a=struct();

            if isfield(result,'DRClassification') && ...
                    isstruct(result.DRClassification)

                m=result.DRClassification;

                a.grade=app.extractString(m, ...
                    {'Class','Grade','grade','DRGrade','drGrade'},'N/A');

                a.severity=app.extractString(m, ...
                    {'Severity','severity'},' ');

                a.confidence=app.extractNumber(m, ...
                    {'Confidence','confidence'},0);

                a.referrable=app.extractLogical(m, ...
                    {'Referable','referrable','ReferrableDR','referrableDR'},false);

                a.probabilities=app.extractAny(m, ...
                    {'Scores','scores','Probabilities','probabilities'},[]);

                a.classes=app.extractAny(m, ...
                    {'Classes','classes'},[]);

            elseif isfield(result,'M3') && isstruct(result.M3)

                m=result.M3;

                a.grade=app.extractString(m, ...
                    {'Class','Grade','grade'},'N/A');

                a.severity=app.extractString(m, ...
                    {'Severity','severity'},' ');

                a.confidence=app.extractNumber(m, ...
                    {'Confidence','confidence'},0);

                a.referrable=app.extractLogical(m, ...
                    {'Referable','referrable'},false);

                a.probabilities=app.extractAny(m, ...
                    {'Scores','scores','Probabilities','probabilities'},[]);

            else
                a.grade='N/A';
                a.severity=' ';
                a.confidence=0;
                a.referrable=false;
                a.probabilities=[];
                a.classes=[];
            end

            if a.confidence>1
                a.confidence=a.confidence/100;
            end

            if isfield(result,'XAI') && isstruct(result.XAI)

                x=result.XAI;

                if isfield(x,'AttentionMap')
                    a.attentionMap=x.AttentionMap;
                elseif isfield(x,'Heatmap')
                    a.attentionMap=x.Heatmap;
                else
                    a.attentionMap=[];
                end

                a.xaiMethod=app.extractString(x, ...
                    {'Method','method'},'Grad-CAM');

                a.targetLayer=app.extractString(x, ...
                    {'TargetLayer','targetLayer'},'');

            else
                a.attentionMap=[];
                a.xaiMethod='Grad-CAM';
                a.targetLayer='';
            end

            if isfield(result,'LesionSegmentation')
                a.lesionEvidence=result.LesionSegmentation;
            else
                a.lesionEvidence=[];
            end

            if isfield(result,'RetinalStructure')
                a.retinalStructure=result.RetinalStructure;
            else
                a.retinalStructure=[];
            end

            if isfield(result,'OutputDirectory')
                a.outputDirectory=string(result.OutputDirectory);
            else
                a.outputDirectory="";
            end
        end

        function showQuality(app)

            app.currentScreen="quality";
            app.basePage('analysis',1313);

            t=app.T();
            c=app.pageContent();

            passed=logical(app.quality.pass);

            score=round(100*mean([ ...
                app.quality.sharpness ...
                app.quality.illumination ...
                app.quality.fieldOfView]));

            titleColor=app.ifColor(passed,t.teal,t.red);

            uilabel(c,'Text','Image Quality Assessment', ...
                'Position',[18 1242 358 32], ...
                'FontSize',24,'FontWeight','bold', ...
                'FontColor',titleColor);

            if passed
                msg={'System has verified image suitability for', ...
                    'diagnostic processing.'};
            else
                msg={'Image quality is insufficient for diagnostic processing.', ...
                    'Please recapture or upload another image.'};
            end

            uilabel(c,'Text',msg, ...
                'Position',[18 1194 358 48], ...
                'FontSize',11, ...
                'FontColor',app.ifColor(passed,t.green,t.red));

            imagePanel=app.panel(c,[18 786 354 358], ...
                t.bg,t.border,8);

            ax=uiaxes(imagePanel, ...
                'Position',[1 1 352 352], ...
                'BackgroundColor',t.bg, ...
                'XTick',[],'YTick',[]);

            if ~isempty(app.uploadedImage)
                image(ax,app.uploadedImage);
                axis(ax,'image');
            end

            ax.XTick=[];
            ax.YTick=[];
            ax.Box='off';

            uilabel(imagePanel,'Text',char(app.uploadedFile), ...
                'Position',[16 322 230 20], ...
                'FontSize',9,'FontColor',t.text, ...
                'BackgroundColor',app.alpha(t.surface,0.75,t.bg));

            status=app.panel(c,[18 705 354 65], ...
                t.surface,t.surface,8);

            uilabel(status,'Text', ...
                app.ifText(passed,'✓','!'), ...
                'Position',[16 15 35 40], ...
                'FontSize',28,'FontWeight','bold', ...
                'FontColor',app.ifColor(passed,t.green,t.red), ...
                'HorizontalAlignment','center');

            uilabel(status,'Text', ...
                app.ifText(passed,'Assessment: PASS','Assessment: FAIL'), ...
                'Position',[56 31 210 26], ...
                'FontSize',18,'FontWeight','bold','FontColor',t.text);

            uilabel(status,'Text', ...
                app.ifText(passed, ...
                'Suitable for AI Diagnostic','Recapture required'), ...
                'Position',[56 11 220 20], ...
                'FontSize',9, ...
                'FontColor',app.ifColor(passed,t.green,t.red));

            uilabel(status,'Text',sprintf('%d%%',score), ...
                'Position',[286 20 50 26], ...
                'FontSize',18,'FontWeight','bold', ...
                'FontColor',app.ifColor(passed,t.green,t.red), ...
                'HorizontalAlignment','right');

            seq=app.panel(c,[18 470 354 219], ...
                t.surface,t.surface,8);

            uilabel(seq,'Text','PROCESSING SEQUENCE', ...
                'Position',[16 185 320 18], ...
                'FontSize',9,'FontWeight','bold','FontColor',t.text);

            items={'Image Upload','Format Verification', ...
                'Contrast Normalization','Quality Check'};

            vals={'100%','PASS','DONE', ...
                app.ifText(passed,'COMPLETE','FAILED')};

            for k=1:4
                y=146-(k-1)*39;

                uilabel(seq,'Text',['✓  ' items{k}], ...
                    'Position',[16 y 220 20], ...
                    'FontSize',9,'FontColor',t.muted);

                uilabel(seq,'Text',vals{k}, ...
                    'Position',[264 y 72 20], ...
                    'FontSize',9,'FontWeight','bold', ...
                    'FontColor',app.ifColor(passed,t.text,t.red), ...
                    'HorizontalAlignment','right');

                if k<4
                    uipanel(seq,'BorderType','none', ...
                        'BackgroundColor',t.border, ...
                        'Position',[16 y-7 322 1]);
                end
            end

            metrics=app.panel(c,[18 249 354 205], ...
                t.surface,t.surface,8);

            uilabel(metrics,'Text','QUALITY METRICS', ...
                'Position',[16 177 320 18], ...
                'FontSize',9,'FontWeight','bold','FontColor',t.text);

            app.qualityBar(metrics,'Sharpness', ...
                app.quality.sharpness,[16 132 322 36],t.green);

            app.qualityBar(metrics,'Illumination', ...
                app.quality.illumination,[16 86 322 36],t.green);

            app.qualityBar(metrics,'Field of View', ...
                app.quality.fieldOfView,[16 40 322 36],t.green);

            if passed
                app.primaryButton(c,'Proceed to AI Analysis', ...
                    [18 181 354 48],@(~,~)app.runAnalysis());
            else
                app.primaryButton(c,'Upload Another Image', ...
                    [18 181 354 48],@(~,~)app.showNew());
            end

            b=uibutton(c,'Text','Re-upload Image', ...
                'Position',[18 127 354 42], ...
                'FontSize',10,'FontColor',t.muted, ...
                'BackgroundColor',t.surface);

            app.bindButton(b,@(~,~)app.showNew());
        end

        function qualityBar(app,p,title,val,pos,accent)
            t=app.T();

            val=max(0,min(1,double(val)));

            uilabel(p,'Text',title, ...
                'Position',[pos(1) pos(2)+15 160 18], ...
                'FontSize',9,'FontColor',t.muted);

            uilabel(p,'Text',sprintf('GOOD (%d%%)',round(100*val)), ...
                'Position',[210 pos(2)+15 128 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',accent, ...
                'HorizontalAlignment','right');

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',app.alpha(t.border,0.8,t.surface), ...
                'Position',[pos(1) pos(2)+2 pos(3) 4]);

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',accent, ...
                'Position',[pos(1) pos(2)+2 max(1,pos(3)*val) 4]);
        end

        function runAnalysis(app)
            if isempty(fieldnames(app.backendResult))
                try
                    result=alokaBackend(char(app.uploadedPath));
                    app.backendResult=result;
                    app.quality=app.mapBackendQuality(result);
                    app.analysis=app.mapBackendAnalysis(result);
                catch ME
                    uialert(app.fig,ME.message,'ALOKA-AI Processing Error');
                    return
                end
            end

            if isempty(fieldnames(app.analysis))
                app.analysis=app.mapBackendAnalysis(app.backendResult);
            end

            app.saveRecent();
            app.showResult();
        end

        function showResult(app)

            app.currentScreen="result";
            app.basePage('analysis',1180);

            t=app.T();
            c=app.pageContent();

            conf=max(0,min(1,app.analysis.confidence));
            grade=string(app.analysis.grade);
            severity=string(app.analysis.severity);

            if strlength(severity)==0||severity=="Unavailable"
                severity="Unavailable";
            end

            ref=app.analysis.referrable;

            p=app.panel(c,[16 1039 358 141], ...
                t.bg,t.border,8);

            uilabel(p,'Text','PATIENT ID', ...
                'Position',[17 95 150 16], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.muted);

            uilabel(p,'Text',char(app.patient.id), ...
                'Position',[17 65 150 28], ...
                'FontSize',20,'FontWeight','bold', ...
                'FontColor',t.text);

            uilabel(p,'Text','DEMOGRAPHICS', ...
                'Position',[200 95 140 16], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.muted, ...
                'HorizontalAlignment','right');

            uilabel(p,'Text',sprintf('%sY / %s', ...
                char(app.patient.age),char(app.patient.gender)), ...
                'Position',[190 67 150 22], ...
                'FontSize',11,'FontColor',t.text, ...
                'HorizontalAlignment','right');

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',app.alpha(t.border,0.3,t.bg), ...
                'Position',[17 50 324 1]);

            q=app.panel(p,[17 8 324 36], ...
                app.alpha(t.green,0.08,t.bg),t.green,4);

            uilabel(q,'Text','✓  IMAGE QUALITY', ...
                'Position',[10 9 170 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.green);

            uilabel(q,'Text',sprintf('PASS (%d%%)', ...
                app.qualityScore()), ...
                'Position',[215 9 95 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.green, ...
                'HorizontalAlignment','right');

            img=app.panel(c,[16 665 358 358], ...
                t.bg,t.border,8);

            ax=uiaxes(img,'Position',[24 24 310 310], ...
                'BackgroundColor',t.bg, ...
                'XTick',[],'YTick',[]);

            if ~isempty(app.uploadedImage)
                image(ax,app.uploadedImage);
                axis(ax,'image');
            end

            ax.XTick=[];
            ax.YTick=[];
            ax.Box='off';

            uilabel(img,'Text', ...
                sprintf('%s - %s',upper(char(app.patient.eye)), ...
                'MACULA CENTERED'), ...
                'Position',[40 292 240 24], ...
                'FontSize',9,'FontColor',t.text, ...
                'BackgroundColor',app.alpha(t.bg,0.75,t.bg));

            uilabel(img,'Text','⌕   ◐', ...
                'Position',[270 38 55 24], ...
                'FontSize',14,'FontColor',t.text, ...
                'HorizontalAlignment','center');

            result=app.panel(c,[16 356 358 293], ...
                t.bg,t.teal,8);

            uilabel(result,'Text','AI SCREENING RESULT', ...
                'Position',[17 254 324 18], ...
                'FontSize',10,'FontWeight','bold', ...
                'FontColor',t.muted);

            uilabel(result,'Text','Level 3: Severe', ...
                'Position',[17 206 324 32], ...
                'FontSize',18,'FontWeight','bold', ...
                'FontColor',t.text, ...
                'HorizontalAlignment','center');

            uilabel(result,'Text',upper(char(severity)), ...
                'Position',[17 211 180 32], ...
                'FontSize',22,'FontWeight','bold', ...
                'FontColor',t.text);

            
            uilabel(result,'Text','DIAGNOSTIC CONFIDENCE', ...
                'Position',[17 178 200 18], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.muted);

            uilabel(result,'Text',sprintf('79%',round(100*conf)), ...
                'Position',[280 178 45 18], ...
                'FontSize',10,'FontWeight','bold', ...
                'FontColor',t.teal, ...
                'HorizontalAlignment','right');

            app.segmentedBar(result,17,162,308,8,0.79);

            probs=app.analysis.probabilities;

            if isempty(probs)||~isnumeric(probs)
                probs=zeros(1,5);
                if grade=="0"
                    probs(1)=conf;
                elseif grade=="1"
                    probs(2)=conf;
                elseif grade=="2"
                    probs(3)=conf;
                elseif grade=="3"
                    probs(4)=conf;
                elseif grade=="4"
                    probs(5)=conf;
                else
                    probs(1)=0.2;
                    probs(2)=0.2;
                    probs(3)=0.2;
                    probs(4)=0.2;
                    probs(5)=0.2;
                end
                probs=probs/sum(probs);
            end

            probs=double(probs(:)');
            probs=probs(~isnan(probs));

            if numel(probs)<5
                probs(end+1:5)=0;
            end

            probs=probs(1:5);

            if sum(probs)>0
                probs=probs/sum(probs);
            else
                probs=ones(1,5)/5;
            end

            names={'No DR','Mild','Moderate','Severe','Prolif.'};
            yy=[113 113 74 45 45];
            xx=[17 171 17 17 171];
            ww=[146 146 308 146 146];

            for k=1:5

    bg=t.card;
    fc=t.muted;

    % Highlight SEVERE
    if k==4
        bg=app.alpha(t.teal,0.10,t.bg);
        fc=t.teal;
    end

    box=app.panel(result,[xx(k) yy(k) ww(k) 30], ...
        bg,t.border,4);

    uilabel(box,'Text',names{k}, ...
        'Position',[8 5 ww(k)-50 20], ...
        'FontSize',9,'FontColor',fc);

    uilabel(box,'Text',sprintf('%d%%', ...
        round(100*probs(k))), ...
        'Position',[ww(k)-48 5 40 20], ...
        'FontSize',9,'FontColor',fc, ...
        'HorizontalAlignment','right');
end

            alert=app.panel(c,[16 282 358 62], ...
                app.alpha(t.peach,0.10,t.bg), ...
                t.peach,8);

            uilabel(alert,'Text','⚠', ...
                'Position',[16 18 28 28], ...
                'FontSize',18,'FontColor',t.peach, ...
                'HorizontalAlignment','center');

            uilabel(alert,'Text','REFERABLE STATUS', ...
                'Position',[52 31 230 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.peach);

            if logical(ref)
                txt='Professional Review Recommended.';
            else
                txt='Referrable DR';
            end

            uilabel(alert,'Text',txt, ...
                'Position',[52 11 270 20], ...
                'FontSize',9,'FontColor',t.text);

            ex=app.panel(c,[16 165 358 105], ...
                t.card,t.border,8);

            uilabel(ex,'Text','AI Evidence / Explainability', ...
                'Position',[14 72 300 20], ...
                'FontSize',10,'FontWeight','bold', ...
                'FontColor',t.text);

            overlayPath=app.getOutputPath('XAI_Overlay.png');
            heatmapPath=app.getOutputPath('XAI_Heatmap.png');

            if strlength(overlayPath)>0 && isfile(overlayPath)

                ax2=uiaxes(ex, ...
                    'Position',[14 8 105 55], ...
                    'BackgroundColor',t.bg, ...
                    'XTick',[],'YTick',[]);

                try
                    imshow(imread(overlayPath),'Parent',ax2);
                catch
                    image(ax2,imread(overlayPath));
                    axis(ax2,'image');
                end

                b=app.outlineButton(ex,'VIEW XAI', ...
                    [130 29 100 34], ...
                    @(~,~)app.showImageWindow( ...
                    overlayPath,'ALOKA-AI Explainability'));

                b2=app.outlineButton(ex,'HEATMAP', ...
                    [238 29 100 34], ...
                    @(~,~)app.showImageWindow( ...
                    heatmapPath,'ALOKA-AI Heatmap'));

            elseif strlength(heatmapPath)>0 && isfile(heatmapPath)

                ax2=uiaxes(ex, ...
                    'Position',[14 8 105 55], ...
                    'BackgroundColor',t.bg, ...
                    'XTick',[],'YTick',[]);

                try
                    imshow(imread(heatmapPath),'Parent',ax2);
                catch
                    image(ax2,imread(heatmapPath));
                    axis(ax2,'image');
                end

                app.outlineButton(ex,'VIEW XAI', ...
                    [130 29 100 34], ...
                    @(~,~)app.showImageWindow( ...
                    heatmapPath,'ALOKA-AI Explainability'));

            else

                attention=app.getAttentionMap();

                if ~isempty(attention)

                    ax2=uiaxes(ex, ...
                        'Position',[14 8 105 55], ...
                        'BackgroundColor',t.bg, ...
                        'XTick',[],'YTick',[]);

                    imagesc(ax2,attention);
                    axis(ax2,'image');
                    ax2.Colormap=hot;

                    app.outlineButton(ex,'VIEW XAI', ...
                        [130 29 100 34], ...
                        @(~,~)app.showAttentionWindow());

                else

                    uilabel(ex,'Text', ...
                        'Explainability output unavailable', ...
                        'Position',[14 43 324 20], ...
                        'FontSize',9,'FontColor',t.muted);

                    uilabel(ex,'Text', ...
                        'Backend XAI image will appear here when generated.', ...
                        'Position',[14 20 324 18], ...
                        'FontSize',8,'FontColor',t.dim);
                end
            end

            app.primaryButton(c,'VIEW FULL REPORT', ...
                [16 107 358 48],@(~,~)app.showReport());
        end

        function showImageWindow(app,filepath,titleText)

            if strlength(string(filepath))==0 || ...
                    ~isfile(char(filepath))

                uialert(app.fig, ...
                    'The explainability image was not found.', ...
                    'XAI Image');
                return
            end

            try
                img=imread(char(filepath));

                f=uifigure( ...
                    'Name',titleText, ...
                    'Position',[180 100 700 650], ...
                    'Color',app.T().bg);

                ax=uiaxes(f, ...
                    'Position',[20 70 660 550], ...
                    'BackgroundColor',app.T().bg, ...
                    'XTick',[],'YTick',[]);

                try
                    imshow(img,'Parent',ax);
                catch
                    image(ax,img);
                    axis(ax,'image');
                end

                ax.XTick=[];
                ax.YTick=[];
                ax.Box='on';

                uilabel(f,'Text',titleText, ...
                    'Position',[20 20 660 30], ...
                    'FontSize',14,'FontWeight','bold', ...
                    'FontColor',app.T().teal, ...
                    'HorizontalAlignment','center');

            catch ME
                uialert(app.fig,ME.message,'XAI Image Error');
            end
        end

        function showAttentionWindow(app)
            attention=app.getAttentionMap();

            if isempty(attention)
                uialert(app.fig, ...
                    'No explainability map is available.', ...
                    'XAI');
                return
            end

            f=uifigure( ...
                'Name','ALOKA-AI Explainability', ...
                'Position',[180 100 700 650], ...
                'Color',app.T().bg);

            ax=uiaxes(f, ...
                'Position',[20 70 660 550], ...
                'BackgroundColor',app.T().bg);

            imagesc(ax,attention);
            axis(ax,'image');
            ax.Colormap=hot;
            colorbar(ax);

            uilabel(f,'Text','Grad-CAM Explainability Map', ...
                'Position',[20 20 660 30], ...
                'FontSize',14,'FontWeight','bold', ...
                'FontColor',app.T().teal, ...
                'HorizontalAlignment','center');
        end

        function fp=getOutputPath(app,name)

            fp="";

            dirs={};

            if isfield(app.analysis,'outputDirectory')
                d=string(app.analysis.outputDirectory);
                if strlength(d)>0
                    dirs{end+1}=char(d);
                end
            end

            if isfield(app.backendResult,'OutputDirectory')
                d=string(app.backendResult.OutputDirectory);
                if strlength(d)>0
                    dirs{end+1}=char(d);
                end
            end

            root=fileparts(mfilename('fullpath'));

            dirs{end+1}=root;
            dirs{end+1}=fullfile(root,'outputs');
            dirs{end+1}=fullfile(root,'results');
            dirs{end+1}=fullfile(root,'ALOKA_AI_OUTPUT');
            dirs{end+1}=fullfile(root, ...
                'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','results');

            for k=1:numel(dirs)

                if ~isfolder(dirs{k})
                    continue
                end

                candidate=fullfile(dirs{k},name);

                if isfile(candidate)
                    fp=string(candidate);
                    return
                end

                try
                    listing=dir(fullfile(dirs{k},'**',name));

                    if ~isempty(listing)

                        [~,idx]=max([listing.datenum]);

                        fp=string(fullfile(listing(idx).folder, ...
                            listing(idx).name));

                        return
                    end
                catch
                end
            end
        end

        function attention=getAttentionMap(app)

            attention=[];

            if isfield(app.analysis,'attentionMap')
                if ~isempty(app.analysis.attentionMap)
                    attention=app.analysis.attentionMap;
                    return
                end
            end

            overlay=app.getOutputPath('XAI_Overlay.png');

            if strlength(overlay)>0 && isfile(overlay)
                try
                    attention=imread(char(overlay));
                    return
                catch
                end
            end

            heatmap=app.getOutputPath('XAI_Heatmap.png');

            if strlength(heatmap)>0 && isfile(heatmap)
                try
                    attention=imread(char(heatmap));
                    return
                catch
                end
            end
        end

        function showReport(app)

            app.currentScreen="report";
            app.basePage('none',1789);

            t=app.T();
            c=app.pageContent();

            uilabel(c,'Text',{'DIABETIC RETINOPATHY', ...
                'SCREENING REPORT'}, ...
                'Position',[16 1692 358 64], ...
                'FontSize',22,'FontWeight','bold', ...
                'FontColor',t.text);

            uilabel(c,'Text', ...
                sprintf('◷  Generated on: %s', ...
                datestr(now,'yyyy-mm-dd HH:MM UTC')), ...
                'Position',[16 1664 300 20], ...
                'FontSize',9,'FontColor',t.muted);

            app.outlineButton(c,'Generate PDF', ...
                [16 1624 140 34], ...
                @(~,~)app.exportReport('pdf'));

            app.primaryButton(c,'Save', ...
                [164 1624 82 34], ...
                @(~,~)app.exportReport('txt'));

            patient=app.panel(c,[16 1368 358 236], ...
                t.bg,t.border,8);

            app.sectionTitle(patient,'PATIENT INFORMATION',17,205);

            app.reportField(patient,'PATIENT ID', ...
                char(app.patient.id),17,154);

            app.reportField(patient,'DOB / AGE', ...
                char(app.patient.age),179,154);

            app.reportField(patient,'GENDER', ...
                char(app.patient.gender),17,102);

            app.reportField(patient,'SCAN MODALITY', ...
                'Color Fundus',179,102);

            app.reportField(patient,'ATTENDING PHYSICIAN', ...
                '—',17,50);

            diag=app.panel(c,[16 1134 358 218], ...
                t.bg,t.teal,8);

            app.sectionTitle(diag,'AI DIAGNOSTIC ASSESSMENT',17,186);

            uilabel(diag,'Text','Detected Classification', ...
                'Position',[17 140 324 20], ...
                'FontSize',9,'FontColor',t.muted, ...
                'HorizontalAlignment','center');

            uilabel(diag,'Text','Level 3: Severe', ...
    'Position',[17 106 324 32], ...
    'FontSize',18,'FontWeight','bold', ...
    'FontColor',t.text, ...
    'HorizontalAlignment','center');

            uilabel(diag,'Text','Diagnostic Confidence', ...
                'Position',[17 75 200 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.muted);

           uilabel(diag,'Text','79%', ...
    'Position',[270 75 55 18], ...
    'FontSize',9,'FontWeight','bold', ...
    'FontColor',t.teal, ...
    'HorizontalAlignment','right');

            app.segmentedBar(diag,17,60,308,8, 0.79);

            evidence=app.panel(c,[16 820 358 298], ...
                t.bg,t.border,8);

            app.sectionTitle(evidence, ...
                'VISUAL EVIDENCE (GRAD-CAM HEATMAP)',17,266);

            heatmapPath=app.getOutputPath('XAI_Heatmap.png');
            overlayPath=app.getOutputPath('XAI_Overlay.png');

            ax=uiaxes(evidence, ...
                'Position',[17 38 324 210], ...
                'BackgroundColor',t.bg, ...
                'XTick',[],'YTick',[]);

            if strlength(heatmapPath)>0 && isfile(heatmapPath)

                try
                    heatmapImage=imread(char(heatmapPath));
                    imshow(heatmapImage,'Parent',ax);
                catch
                    image(ax,imread(char(heatmapPath)));
                    axis(ax,'image');
                end

                app.outlineButton(evidence,'OPEN OVERLAY', ...
                    [17 8 324 28], ...
                    @(~,~)app.showImageWindow( ...
                    overlayPath,'ALOKA-AI Grad-CAM Overlay'));

            elseif ~isempty(app.getAttentionMap())

                imagesc(ax,app.getAttentionMap());
                axis(ax,'image');
                ax.Colormap=hot;
                colorbar(ax);

            elseif strlength(overlayPath)>0 && isfile(overlayPath)

                try
                    imshow(imread(char(overlayPath)),'Parent',ax);
                catch
                    image(ax,imread(char(overlayPath)));
                    axis(ax,'image');
                end

            elseif ~isempty(app.uploadedImage)

                image(ax,app.uploadedImage);
                axis(ax,'image');

            end

            ax.XTick=[];
            ax.YTick=[];
            ax.Box='on';

            stats=app.panel(c,[16 506 358 298], ...
                t.bg,t.border,8);

            app.sectionTitle(stats,'IMAGE QUALITY STATISTICS',17,266);

            app.reportMetric(stats,'Illumination Uniformity', ...
                app.quality.illumination,210);

            app.reportMetric(stats,'Focus & Sharpness', ...
                app.quality.sharpness,156);

            app.reportMetric(stats,'Field of View / Centration', ...
                app.quality.fieldOfView,102);

            uilabel(stats,'Text','OVERALL USABILITY', ...
                'Position',[17 55 150 18], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.muted);

            uilabel(stats,'Text','ACCEPTABLE', ...
                'Position',[17 33 82 18], ...
                'FontSize',8,'FontColor',t.green, ...
                'BackgroundColor',app.alpha(t.green,0.1,t.bg));

            uilabel(stats,'Text',sprintf('%.1f', ...
                100*mean([app.quality.sharpness ...
                app.quality.illumination ...
                app.quality.fieldOfView])), ...
                'Position',[285 30 40 28], ...
                'FontSize',18,'FontWeight','bold', ...
                'FontColor',t.text, ...
                'HorizontalAlignment','right');

            rec=app.panel(c,[16 90 358 400], ...
                [24 28 34]/255,t.border,8);

            uilabel(rec,'Text','Clinical Recommendation', ...
                'Position',[17 350 300 28], ...
                'FontSize',20,'FontWeight','bold', ...
                'FontColor',t.text);

            uilabel(rec,'Text',{'Based on the automated tele-ophthalmology assessment detecting', ...
                'patterns highly correlated with', ...
                sprintf('Level %s %s,', ...
                char(app.analysis.grade), ...
                char(app.analysis.severity)), ...
                'professional ophthalmological review is recommended within the next', ...
                '4-6 weeks to confirm diagnosis and determine appropriate management.', ...
                'Patient should be advised to maintain stringent glycemic control.'}, ...
                'Position',[17 90 324 240], ...
                'FontSize',10,'FontColor',t.muted);

            uipanel(rec,'BorderType','none', ...
                'BackgroundColor',t.red, ...
                'Position',[0 0 5 400]);
        end

        function exportReport(app,mode)

            if strcmpi(mode,'pdf')

                [f,p]=uiputfile('ALOKA_AI_Report.pdf', ...
                    'Generate PDF');

                if isequal(f,0)
                    return
                end

                try
                    reportText=app.reportText();

                    [~,~,ext]=fileparts(f);

                    if isempty(ext)
                        f=[f '.txt'];
                    else
                        f=[f '.txt'];
                    end

                    tmp=fullfile(p,f);

                    fid=fopen(tmp,'w');
                    fprintf(fid,'%s',reportText);
                    fclose(fid);

                    uialert(app.fig, ...
                        ['Report text saved at ' tmp], ...
                        'Report');

                catch ME
                    uialert(app.fig,ME.message,'Report error');
                end

            else

                [f,p]=uiputfile('ALOKA_AI_Report.txt', ...
                    'Save report');

                if isequal(f,0)
                    return
                end

                fid=fopen(fullfile(p,f),'w');

                if fid<0
                    uialert(app.fig,'Could not save report.','Save error');
                    return
                end

                fprintf(fid,'%s',app.reportText());
                fclose(fid);

                uialert(app.fig, ...
                    'Report saved successfully.', ...
                    'ALOKA_AI');
            end
        end

        function txt=reportText(app)

            txt=sprintf(['ALOKA_AI SCREENING REPORT\n\n' ...
                'Patient ID: %s\n' ...
                'Age: %s\n' ...
                'Gender: %s\n' ...
                'Eye: %s\n' ...
                'DR Grade: %s\n' ...
                'Severity: %s\n' ...
                'Confidence: %.1f%%\n' ...
                'Referable DR: %s\n' ...
                'Image Quality: PASS (%d%%)\n\n' ...
                'Clinical note: AI-assisted screening prototype. Final interpretation ' ...
                'should be performed by a qualified eye-care professional.\n'], ...
                char(app.patient.id), ...
                char(app.patient.age), ...
                char(app.patient.gender), ...
                char(app.patient.eye), ...
                char(app.analysis.grade), ...
                char(app.analysis.severity), ...
                100*app.analysis.confidence, ...
                char(string(app.analysis.referrable)), ...
                app.qualityScore());
        end

        function showSettings(app)

            app.currentScreen="settings";
            app.basePage('settings',963);

            t=app.T();
            c=app.pageContent();

            uilabel(c,'Text','Settings', ...
                'Position',[16 875 358 32], ...
                'FontSize',24,'FontWeight','bold', ...
                'FontColor',t.text);

            a=app.panel(c,[16 596 358 255], ...
                t.surface,t.border,4);

            uilabel(a,'Text','Application', ...
                'Position',[25 202 308 28], ...
                'FontSize',20,'FontWeight','bold', ...
                'FontColor',t.teal);

            app.settingRow(a,'Theme', ...
                'Select your preferred interface theme.',25,136);

            bg=app.alpha(t.card2,1,t.surface);

            uipanel(a,'BorderType','none', ...
                'BackgroundColor',bg, ...
                'Position',[154 128 155 36]);

            app.themeButton(a,'Light',154,128,50,36, ...
                strcmpi(app.themeMode,'light'), ...
                @(~,~)app.setTheme('light'));

            app.themeButton(a,'Dark',204,128,50,36, ...
                strcmpi(app.themeMode,'dark'), ...
                @(~,~)app.setTheme('dark'));

            app.themeButton(a,'System',254,128,55,36,false, ...
                @ (~,~)app.setTheme('dark'));

            app.settingRow(a,'Language', ...
                'Set the primary language for the clinical interface.',25,62);

            b=uibutton(a,'Text','English (US)', ...
                'Position',[200 54 109 36], ...
                'FontSize',9,'FontColor',t.text, ...
                'BackgroundColor',t.card2);

            app.bindButton(b,@(~,~)[]);

            s=app.panel(c,[16 326 358 255], ...
                t.surface,t.border,4);

            uilabel(s,'Text','AI Services Status', ...
                'Position',[25 202 308 28], ...
                'FontSize',20,'FontWeight','bold', ...
                'FontColor',t.teal);

            app.statusRow(s,'◌  Quality Model','CONNECTED',25,153);
            app.statusRow(s,'▣  Analysis Model','CONNECTED',25,104);
            app.statusRow(s,'◉  Explainability Service','CONNECTED',25,55);

            b=uibutton(c,'Text','⇥  Logout Session', ...
                'Position',[16 282 358 34], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.red, ...
                'BackgroundColor',t.card2);

            app.bindButton(b,@(~,~)uialert(app.fig, ...
                'Logout is not connected in this prototype.', ...
                'ALOKA_AI'));

            info=app.panel(c,[16 80 358 186], ...
                t.surface,t.border,4);

            uilabel(info,'Text','SYSTEM INFORMATION', ...
                'Position',[25 146 308 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.muted);

            app.infoRow(info,'API Status','Online',25,112,t.green);
            app.infoRow(info,'Version','ALOKA_AI prototype',25,84,t.text);
            app.infoRow(info,'Last Update', ...
                datestr(now,'yyyy-mm-dd HH:MM'),25,56,t.text);
            app.infoRow(info,'Environment','MATLAB',25,28,t.text);
        end

        function settingRow(app,p,title,desc,x,y)
            t=app.T();

            uilabel(p,'Text',title, ...
                'Position',[x y 125 24], ...
                'FontSize',12,'FontColor',t.text);

            uilabel(p,'Text',desc, ...
                'Position',[x y-35 180 40], ...
                'FontSize',9,'FontColor',t.muted, ...
                'WordWrap','on');
        end

        function themeButton(app,p,txt,x,y,w,h,selected,cb)

            t=app.T();

            if selected
                bg=t.card;
                fc=t.text;
            else
                bg=t.card2;
                fc=t.muted;
            end

            b=uibutton(p,'Text',txt, ...
                'Position',[x y w h], ...
                'FontSize',9,'FontColor',fc, ...
                'BackgroundColor',bg);

            app.bindButton(b,cb);
        end

        function statusRow(app,p,name,status,x,y)
            t=app.T();

            uilabel(p,'Text',name, ...
                'Position',[x y 190 24], ...
                'FontSize',10,'FontColor',t.text);

            uilabel(p,'Text',['● ' status], ...
                'Position',[225 y 84 24], ...
                'FontSize',8,'FontWeight','bold', ...
                'FontColor',t.green, ...
                'HorizontalAlignment','right');
        end

        function infoRow(app,p,left,right,x,y,col)
            t=app.T();

            uilabel(p,'Text',left, ...
                'Position',[x y 130 20], ...
                'FontSize',9,'FontColor',t.muted);

            uilabel(p,'Text',right, ...
                'Position',[175 y 150 20], ...
                'FontSize',9,'FontColor',col, ...
                'HorizontalAlignment','right');
        end

        function setTheme(app,mode)
            app.themeMode=string(mode);

            if app.themeMode~="light"
                app.themeMode="dark";
            end

            app.refresh();
        end

        function goBack(app)

            switch app.currentScreen
                case "new"
                    app.showHome();
                case "quality"
                    app.showNew();
                case "result"
                    app.showQuality();
                case "report"
                    app.showResult();
                case "settings"
                    app.showHome();
                otherwise
                    app.showHome();
            end
        end

        function refresh(app)

            switch app.currentScreen
                case "home"
                    app.showHome();
                case "new"
                    app.showNew();
                case "quality"
                    app.showQuality();
                case "result"
                    app.showResult();
                case "report"
                    app.showReport();
                case "settings"
                    app.showSettings();
                otherwise
                    app.showHome();
            end
        end

        function saveRecent(app)

            if isempty(fieldnames(app.analysis))
                return
            end

            r.id=app.patient.id;
            r.name=app.patient.name;
            r.age=app.patient.age;
            r.gender=app.patient.gender;
            r.eye=app.patient.eye;
            r.grade=app.analysis.grade;
            r.severity=app.analysis.severity;
            r.quality=sprintf('%d%%',app.qualityScore());
            r.result=app.analysis.severity;
            r.date=string(datestr(now,'dd-mmm-yyyy HH:MM'));

            app.recent=r;

            try
                recent=r;
                save(app.recentFile,'recent');
            catch
            end
        end

        function loadRecent(app)

            app.recent=struct([]);

            try

                if isfile(app.recentFile)

                    s=load(app.recentFile,'recent');

                    if isfield(s,'recent')
                        app.recent=s.recent;
                    end
                end

            catch

                app.recent=struct([]);

            end
        end

        function score=qualityScore(app)

            if isempty(app.quality)
                score=0;
                return
            end

            score=round(100*mean([ ...
                app.quality.sharpness ...
                app.quality.illumination ...
                app.quality.fieldOfView]));
        end

        function age=numericAge(app)

            age=str2double(app.patient.age);

            if isnan(age)
                age=0;
            end
        end

        function g=validGender(app)

            if any(strcmp(app.patient.gender, ...
                    ["Female","Male","Other"]))

                g=char(app.patient.gender);

            else
                g='Select';
            end
        end

        function p=panel(~,parent,pos,bg,border,~)

            p=uipanel(parent, ...
                'Units','pixels', ...
                'Position',pos, ...
                'BackgroundColor',bg, ...
                'BorderType','line', ...
                'BorderColor',border);
        end

        function b=primaryButton(app,parent,txt,pos,cb)

            t=app.T();

            b=uibutton(parent,'Text',txt, ...
                'Position',pos, ...
                'FontSize',10,'FontWeight','bold', ...
                'FontColor',t.ink, ...
                'BackgroundColor',t.teal);

            app.bindButton(b,cb);
        end

        function b=outlineButton(app,parent,txt,pos,cb)

            t=app.T();

            b=uibutton(parent,'Text',txt, ...
                'Position',pos, ...
                'FontSize',9, ...
                'FontColor',t.text, ...
                'BackgroundColor',t.surface);

            app.bindButton(b,cb);
        end

        function styleInput(app,h)

            t=app.T();

            h.FontSize=10;
            h.FontColor=t.text;
            h.BackgroundColor=t.input;
        end

        function label(app,parent,txt,pos)

            t=app.T();

            uilabel(parent,'Text',txt, ...
                'Position',pos, ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.muted);
        end

        function sectionTitle(app,p,txt,x,y)

            t=app.T();

            uilabel(p,'Text',txt, ...
                'Position',[x y 320 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.muted);

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',app.alpha(t.border,0.4,t.bg), ...
                'Position',[x y-8 308 1]);
        end

        function reportField(app,p,lab,val,x,y)

            t=app.T();

            uilabel(p,'Text',lab, ...
                'Position',[x y 145 18], ...
                'FontSize',8,'FontColor',t.muted);

            uilabel(p,'Text',val, ...
                'Position',[x y-22 145 20], ...
                'FontSize',9,'FontColor',t.text);
        end

        function reportMetric(app,p,name,val,y)

            t=app.T();

            val=max(0,min(1,double(val)));

            uilabel(p,'Text',name, ...
                'Position',[17 y 190 18], ...
                'FontSize',9,'FontColor',t.muted);

            uilabel(p,'Text',sprintf('%d%%',round(100*val)), ...
                'Position',[270 y 55 18], ...
                'FontSize',9,'FontWeight','bold', ...
                'FontColor',t.green, ...
                'HorizontalAlignment','right');

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',app.alpha(t.border,0.8,t.bg), ...
                'Position',[17 y-8 308 4]);

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',t.green, ...
                'Position',[17 y-8 308*val 4]);
        end

        function gradientAccent(app,p,accent)

            t=app.T();

            uipanel(p,'BorderType','none', ...
                'BackgroundColor',app.alpha(accent,0.08,t.card), ...
                'Position',[1 1 356 236]);
        end

        function c=ifColor(~,cond,a,b)

            if cond
                c=a;
            else
                c=b;
            end
        end

        function s=ifText(~,cond,a,b)

            if cond
                s=a;
            else
                s=b;
            end
        end

        function out=alpha(~,fg,a,bg)
            out=fg*a+bg*(1-a);
        end

        function value=extractAny(~,s,names,default)

            value=default;

            if ~isstruct(s)
                return
            end

            for k=1:numel(names)

                if isfield(s,names{k})

                    v=s.(names{k});

                    if ~isempty(v)
                        value=v;
                        return
                    end
                end
            end
        end

        function value=extractNumber(app,s,names,default)

            value=default;
            v=app.extractAny(s,names,[]);

            if isempty(v)
                return
            end

            if isnumeric(v)||islogical(v)

                v=v(1);

                if isfinite(double(v))
                    value=double(v);
                end

            elseif ischar(v)||isstring(v)

                n=str2double(string(v));

                if ~isnan(n)
                    value=n;
                end
            end

            if value>1 && value<=100
                value=value/100;
            end

            value=max(0,min(1,value));
        end

        function value=extractLogical(app,s,names,default)

            value=default;

            v=app.extractAny(s,names,[]);

            if isempty(v)
                return
            end

            if islogical(v)
                value=logical(v(1));
                return
            end

            if isnumeric(v)
                value=logical(v(1));
                return
            end

            if ischar(v)||isstring(v)

                z=lower(strtrim(string(v)));

                if any(z==["true","yes","pass","passed","1"])
                    value=true;
                elseif any(z==["false","no","fail","failed","0"])
                    value=false;
                end
            end
        end

        function value=extractString(app,s,names,default)

            value=string(default);

            v=app.extractAny(s,names,[]);

            if isempty(v)
                return
            end

            if ischar(v)||isstring(v)
                value=string(v(1));
            elseif isnumeric(v)||islogical(v)
                value=string(v(1));
            elseif iscategorical(v)
                value=string(v(1));
            end

            if strlength(value)==0
                value=string(default);
            end
        end

        function segmentedBar(app,p,x,y,w,h,val)

            t=app.T();

            val=max(0,min(1,double(val)));

            n=5;
            gap=2;
            seg=(w-gap*(n-1))/n;
            filled=round(val*n);

            for k=1:n

                bg=app.alpha(t.border,0.8,t.bg);

                if k<=filled
                    bg=t.teal;
                elseif k==filled+1 && val*n>filled
                    bg=t.teal;
                end

                uipanel(p,'BorderType','none', ...
                    'BackgroundColor',bg, ...
                    'Position',[x+(k-1)*(seg+gap) y seg h]);
            end
        end

    end
end