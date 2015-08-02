% function run_experiments()

setup;

logPath = fullfile('log','eval0.txt'); 
skipTrain = false; 
skipEval = false; 
ex = struct([]);

% experiment unit: train/evaluate model including view-pooling
ex(end+1).trainOpts = struct(...
    'baseModel', 'imagenet-vgg-m-finetuned-modelnet40phong-BS60_AUGnone', ...
    'dataset', 'modelnet40phong', ...
    'batchSize', 60, ...
    'aug', 'none', ...
    'numEpochs', 10, ...
    'gpuMode', true, ...
    'multiview', true, ...
    'viewpoolLoc', 'fc7', ...
    'learningRate', [1e-4*ones(1,3) 3e-5*ones(1,3) 1e-5*ones(1,3) 1e-6*ones(1,3)], ...
    'momentum', 0.5);
ex(end).featOpts = struct(...
    'dataset', 'modelnet40phong', ...
    'aug', 'none', ...
    'gpuMode', false, ...
    'numWorkers', 12);
ex(end).claOpts = struct(...
    'feat', 'viewpool'); 
ex(end).retOpts = struct(...
    'feat','viewpool',...
    'gpuMode', false, ...
    'numWorkers', 12); 
	
% experiment unit: train/evaluate model without view-pooling:
% for each individual view of one shape, compute minimum distance to all other views of the other shape, 
% then average distances for all views and for both shapes.
ex(end+1).trainOpts = struct(...
    'baseModel', 'imagenet-vgg-m', ...
    'dataset', 'modelnet40phong', ...
    'batchSize', 60, ...
    'aug', 'none', ...
    'numEpochs', 15, ...
    'gpuMode', true);
ex(end).featOpts = struct(...
    'dataset', 'modelnet40phong', ...
    'aug', 'none', ...
    'gpuMode', false, ...
    'numWorkers', 12);
ex(end).claOpts = struct(...
    'feat', 'fc7', ...
    'method', 'avgsvmscore'); 
ex(end).retOpts = struct(...
    'feat','fc7', ...
    'method', 'avgmindist', ...
    'gpuMode', false, ...
    'numWorkers', 12); 
	

for i=1:length(ex), 
    % ---------------------------------------------------------------------
    %                                                    train / fine-tune 
    % ---------------------------------------------------------------------
    if isfield(ex(i),'trainOpts') && ~skipTrain, 
        trainOpts = ex(i).trainOpts;
        prefix = sprintf('BS%d_AUG%s', trainOpts.batchSize, trainOpts.aug);
        if isfield(trainOpts,'multiview') && trainOpts.multiview, 
            prefix = sprintf('%s_MV%s',prefix,trainOpts.viewpoolLoc);
        end
        modelName = sprintf('%s-finetuned-%s-%s', trainOpts.baseModel, ...
            trainOpts.dataset, prefix);
        trainOpts.prefix = prefix;
        if ~exist(fullfile('data','models',[modelName '.mat']),'file'),
            net = run_train(trainOpts.dataset, trainOpts);
            save(fullfile('data','models',[modelName '.mat']),'-struct','net');
        end
        if isfield(ex(i),'featOpts'), ex(i).featOpts.model = modelName; end
    end
    
    % ---------------------------------------------------------------------
    %                                                     compute features 
    % ---------------------------------------------------------------------
    clear feats;
    if isfield(ex(i),'featOpts') && ~skipEval,
        featOpts = ex(i).featOpts;
        featDir = fullfile('data', 'features', ...
            [featOpts.dataset '-' featOpts.model '-' featOpts.aug], 'NORM0');
        if exist(fullfile(featDir, 'prob.mat'),'file'), % supposedly the last
            fprintf('Existing descriptors found at %s \n', featDir);
        end
        feats = imdb_compute_cnn_features(featOpts.dataset, featOpts.model, ...
            'normalization', false, featOpts);
    end
    
    % ---------------------------------------------------------------------
    %                                            classification evaluation
    % ---------------------------------------------------------------------
    if isfield(ex(i),'claOpts') && exist('feats','var') && ~skipEval, 
        claOpts = ex(i).claOpts;
        evalClaPath = fullfile(featDir,claOpts.feat,'evalCla.mat');
        if exist(evalClaPath, 'file'), 
            fprintf('Classification evaluated before at %s \n', evalClaPath);
        else
            if ~isfield(claOpts, 'log2c'), claOpts.log2c = [-8:4:4]; end
            if ~isfield(claOpts, 'cv'), claOpts.cv = 2; end
            if ~isfield(claOpts, 'logPath'), claOpts.logPath = logPath; end
            evaluate_classification(feats.(claOpts.feat), ...
                'predPath', evalClaPath, ...
                claOpts);
        end
    end
    
    % ---------------------------------------------------------------------
    %                                                 retrieval evaluation 
    % ---------------------------------------------------------------------
    if isfield(ex(i),'retOpts') && exist('feats','var') && ~skipEval, 
        retOpts = ex(i).retOpts;
        evalRetPath = fullfile(featDir,retOpts.feat,'evalRet.mat');
        if exist(evalRetPath, 'file'), 
            fprintf('Retrieval evaluated before at %s \n', evalRetPath);
        else
            if ~isfield(retOpts, 'logPath'), retOpts.logPath = logPath; end
            [res,info] = retrieve_shapes_cnn([],feats.(retOpts.feat),retOpts);
            save(evalRetPath,'res','info');
        end
    end
    
end

% delete parallel pool if there is one
delete(gcp('nocreate'));