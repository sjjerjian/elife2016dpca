clear all
load data_romo_eLife.mat  % this file is produced by pfcRomo_preprocess.m
addpath ../dpca/matlab    % path to the dPCA toolkit 
                          % (download from https://github.com/machenslab/dPCA)

% firingRates array is stored in the file in compressed sparse format.
% This line is de-compressing it.
firingRates = reshape(full(firingRates_sparse), firingRates_size);

% Neuron selection criteria used in the eLife paper
D = size(trialNum,1);
minN = min(reshape(trialNum(:,:,:), D, []), [], 2);
meanFiringRate = mean(reshape(firingRatesAverage, D, []), 2);
n = find(minN >= 5 & meanFiringRate < 50);

firingRates = firingRates(n,:,:,:,:);
firingRatesAverage = firingRatesAverage(n,:,:,:);
trialNum = trialNum(n,:,:);

% IMPORTANT NOTE: This yields 788 neurons, instead of 832 as reported in
% the eLife paper. This discrepancy is because we had a mistake in the
% preprocessing script and selected as neurons some auxilliary channels
% that are actually not neurons. This does not influence the results in any
% substantial way, because these auxilliary channels are mostly silent. To
% obtain the same number of units as in the paper, run
% pfcRomo_preprocess.m with electrodeNum = 8 instead of electrodeNum = 7.
% This will yield 832 units.

combinedParams = {{1, [1 3]}, {2, [2 3]}, {3}, {[1 2], [1 2 3]}};
margNames = {'Stimulus', 'Decision', 'Condition-independent', 'Interaction'};
decodingClasses = {[1 1; 2 2; 3 3; 4 4; 5 5; 6 6], [1 2; 1 2; 1 2; 1 2; 1 2; 1 2], [], [1 2; 3 4; 5 6; 7 8; 9 10; 11 12]};
margColours = [23 100 171; 187 20 25; 150 150 150; 114 97 171]/256;

%% Cross-validation to find lambda

% This takes some time (around 4*10 min on my laptop) and produces 
% optimalLambda = 2.5629e-06;

optimalLambda = dpca_optimizeLambda(firingRatesAverage, firingRates, trialNum, ...
    'combinedParams', combinedParams, ...
    'numComps', [10 10 10 10], ...
    'numRep', 10, ...
    'filename', 'tmp_optimalLambdas.mat');

%% dPCA (with regularization and noise cov)

Cnoise = dpca_getNoiseCovariance(firingRatesAverage, firingRates, trialNum, ...
    'type', 'averaged');
  
[W,V,whichMarg] = dpca(firingRatesAverage, 50, ...
    'combinedParams', combinedParams, 'lambda', optimalLambda, 'Cnoise', Cnoise);

explVar = dpca_explainedVariance(firingRatesAverage, W, V, ...
     'combinedParams', combinedParams, ...
     'Cnoise', Cnoise, 'numOfTrials', trialNum);

dpca_plot(firingRatesAverage, W, V, @dpca_plot_romo, ...
    'whichMarg', whichMarg,                 ...
    'time', time,                           ...
    'timeEvents', timeEvents,               ...
    'timeMarginalization', 3,               ...
    'ylims', [150 150 400 150],             ...
    'legendSubplot', 16,                    ...
    'marginalizationNames', margNames,      ...
    'explainedVar', explVar,                ...
    'marginalizationColours', margColours);

%% decoding part

% with 100 iterations this takes around 10*100/60 = 17 min on my laptop

accuracy = dpca_classificationAccuracy(firingRatesAverage, firingRates, trialNum, ...
    'lambda', optimalLambda, ...
    'combinedParams', combinedParams, ...
    'decodingClasses', decodingClasses, ...
    'noiseCovType', 'averaged', ...
    'numRep', 5, ...        % increase to 100
    'filename', 'tmp_classification_accuracy.mat');

dpca_classificationPlot(accuracy, [], [], [], decodingClasses)

% with 100 iterations and 100 shuffles this takes 100 times longer than the
% above function, i.e. 17*100/60 = 28 hours (on my laptop). Be careful.

accuracyShuffle = dpca_classificationShuffled(firingRates, trialNum, ...
    'lambda', optimalLambda, ...
    'combinedParams', combinedParams, ...
    'decodingClasses', decodingClasses, ...
    'noiseCovType', 'averaged', ...
    'numRep', 5, ...        % increase to 100
    'numShuffles', 20, ...  % increase to 100 (takes a lot of time)
    'filename', 'tmp_classification_accuracy.mat');

dpca_classificationPlot(accuracy, [], accuracyShuffle, [], decodingClasses)

componentsSignif = dpca_signifComponents(accuracy, accuracyShuffle, whichMarg);

dpca_plot(firingRatesAverage, W, V, @dpca_plot_default, ...
    'explainedVar', explVar, ...
    'marginalizationNames', margNames, ...
    'marginalizationColours', margColours, ...
    'whichMarg', whichMarg,                 ...
    'time', time,                        ...
    'timeEvents', timeEvents,               ...
    'timeMarginalization', 3,           ...
    'legendSubplot', 16,                ...
    'componentsSignif', componentsSignif);
