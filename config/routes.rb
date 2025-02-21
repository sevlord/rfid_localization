Rfid::Application.routes.draw do
  match 'rr' => 'main#rr_graphs'
  match 'rss' => 'main#rss_graphs'

  match 'correlation' => 'main#rss_rr_correlation'
  match 'regression' => 'main#regression'
  match 'regression_rss_graphs' => 'main#regression_rss_graphs'
  match 'regression_rr_graphs' => 'main#regression_rr_graphs'
  match 'response_probabilities' => 'main#response_probabilities'
  match 'deviations' => 'main#deviations'
  match 'rss_time' => 'main#rss_time'
  match 'rss_coverage' => 'main#rss_coverage'

  match 'algorithm/classifier' => 'algorithm#classifier'
  match 'algorithm/point' => 'algorithm#point_based'
  match 'algorithm/combinational' => 'algorithm#combinational'

  match 'deployment/heuristic' => 'deployment#heuristic'
  match 'deployment/pattern' => 'deployment#pattern'
  match 'deployment/verification' => 'deployment#verification'
  match 'deployment/specific' => 'deployment#specific_pattern'

  root :to => 'main#point_based'
end
