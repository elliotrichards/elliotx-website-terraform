exports.${entry_point} = (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.status(200).json({
    message: 'placeholder deployed by Terraform — replace via CI/CD',
  });
};
