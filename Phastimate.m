function [phase, amplitude] = phastimate(data, D, edge, ord, hilbertwindow, varargin)

if nargin < 6
    offset_correction = 0;
else
    offset_correction = varargin{1};
end
if nargin < 7
    iterations = edge + ceil(hilbertwindow/2);
else
    iterations = varargin{2};
    assert(iterations > edge, 'iterations must be larger than the number of edge samples')
end
if nargin < 8
    armethod = @aryule; %could be aryule, arburg
else
    armethod = varargin{3};
end


% demean the data
data = detrend(data,'constant');

% filter the data
data_filtered = filtfilt(D, data); %note that filtfilt uses reflection and sets the initial values
data_filtered_withoutedge = data_filtered(edge+1:end-edge,:);

% determine AR parameters
[a, e, rc] = armethod(data_filtered_withoutedge, ord);
coefficients = -1 * flip(a(:, 2:end)');

% prepare matrix with the aditional time points for the forward prediction
data_filtered_withoutedge_predicted = [data_filtered_withoutedge; ones(iterations, size(data,2))];
% run the forward prediction
for i = iterations:-1:1
    data_filtered_withoutedge_predicted(end-i+1,:) = ...
        sum(coefficients .* data_filtered_withoutedge_predicted((end-i-ord+1):(end-i),:));
end

% hold on
% plot(data_filtered_withoutedge_predicted, '--')
% plot(data_filtered_withoutedge)

%TODO: de-mean again? Or just demean the window of data used for the
%hilbert transform? Or use a fancier method for detection of the zero line?

data_filtered_withoutedge_predicted_hilbertwindow = data_filtered_withoutedge_predicted(end-hilbertwindow+1:end,:);

% analytic signal and angle
data_filtered_withoutedge_predicted_hilbertwindow_analytic = hilbert(data_filtered_withoutedge_predicted_hilbertwindow);

%plot((size(data_filtered_withoutedge_predicted,1)-hilbertwindow+1):size(data_filtered_withoutedge_predicted,1), angle(data_filtered_withoutedge_predicted_hilbertwindow_analytic).*max(data_filtered_withoutedge_predicted_hilbertwindow(:))/pi)
%xpos = (size(data_filtered_withoutedge_predicted,1)-iterations+edge);
%line([xpos xpos], ylim(gca))

phase = angle(data_filtered_withoutedge_predicted_hilbertwindow_analytic(end-iterations+edge+offset_correction,:));
amplitude = mean(abs(data_filtered_withoutedge_predicted_hilbertwindow_analytic));

end
