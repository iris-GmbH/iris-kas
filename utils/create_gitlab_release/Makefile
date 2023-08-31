dev-packages:
	PIPENV_VENV_IN_PROJECT=1 pipenv sync --categories="packages dev-packages"

coverage: dev-packages
	.venv/bin/python -m coverage run -m pytest --full-trace ./tests
	.venv/bin/python -m coverage report
	.venv/bin/python -m coverage xml
	.venv/bin/python -m coverage html
