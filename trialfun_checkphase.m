function [trl, event] = trialfun_checkphase(cfg)

hdr = ft_read_header(cfg.headerfile);
event = ft_read_event(cfg.headerfile);

EVsample   = [event.sample]';
EVtype     = [event.type];

StimulusStart = find(strcmp('Stimulus', {event.type}));

PreTrig   = round(1 * hdr.Fs);
PostTrig  = round(0.01 * hdr.Fs);

begsample = EVsample(StimulusStart) - PreTrig;
endsample = EVsample(StimulusStart) - PostTrig;

offset = zeros(length(endsample), 1);

trl = [begsample endsample offset];

end 
