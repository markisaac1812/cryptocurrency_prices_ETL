Week 1 Day 1-2
1-ai is so damn powerful
2-def load(rows: list[tuple]) -> int:
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS crypto_raw_data (
        load_id BIGSERIAL PRIMARY KEY,
        extracted_at TIMESTAMPTZ NOT NULL,
        market_date DATE NOT NULL,
        coin_id TEXT,
        symbol TEXT,
        name TEXT,
        current_price_usd NUMERIC,
        market_cap_usd NUMERIC,
        total_volume_usd NUMERIC,
        price_change_percentage_1h NUMERIC,
        price_change_percentage_24h NUMERIC,
        raw_payload JSONB NOT NULL,
        UNIQUE(market_date, coin_id)  -- Prevents duplicate entries for same coin on same day
    );
    """

    insert_sql = """
    INSERT INTO crypto_raw_data (
        extracted_at,
        market_date,
        coin_id,
        symbol,
        name,
        current_price_usd,
        market_cap_usd,
        total_volume_usd,
        price_change_percentage_1h,
        price_change_percentage_24h,
        raw_payload
    ) VALUES %s
    ON CONFLICT (market_date, coin_id) DO UPDATE SET
        extracted_at = EXCLUDED.extracted_at,
        current_price_usd = EXCLUDED.current_price_usd,
        market_cap_usd = EXCLUDED.market_cap_usd,
        total_volume_usd = EXCLUDED.total_volume_usd,
        price_change_percentage_1h = EXCLUDED.price_change_percentage_1h,
        price_change_percentage_24h = EXCLUDED.price_change_percentage_24h,
        raw_payload = EXCLUDED.raw_payload;
    """

    with _get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(create_table_sql)
            execute_values(cur, insert_sql, rows, template=None, page_size=100)
        conn.commit()
    return len(rows)
Okay so here the purpose of this api is to get prices of bitcoin daily so it wouldnt a good idea to override the existing records with new this destroys the purpose of the project hahah. so a better approach make unique constraint on (coin id , market date) so with same day yeah the data will override each other but append to existing data if diffrnet data to compare trends prices etccc
If you run the script twice on the same day → updates the existing row (latest prices)
If you run it on a new day → inserts a new row

Week 1 Day 3-4 (DBT)
1-move profiles.yml in ./dbt hidden folder cause ot holds sensitive data
2-github allows for nested .gitignore files
3-password in profiles.yml if all number put in "" to be string
4-atomic Grain what one row represents
5-dimesnion => discreptive context , facts=> measurable numeric facts
6-{{ref}} jinija dbt template => allow dependency (like first build stg_crypyto_raw in staggin then builds other sql tables dep on this )
7- use dbt.utils instead of MD5 using packages.yml then dbt deps
8- seperate models dir to marts(star_schema) and stagging(for cleaning dat)
9- each dag or each you know auto the fact table records only change but dim tables have its records same 

Week 1 Day 5-7(Airflow)
1-Dockerfile = used when you build your own image
  docker-compose = used when you run existing images together
2-deploy project on EC2 (3lshn akid msh haseb container y run 3la computer kol dah )
3-push docker-compose.yml to github normally(It defines your whole pipeline (Airflow + Postgres + Redis))
4-bug that took 15 hours to solve -> services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    ports:                    # ADD THESE 2 LINES
      - "5433:5432"  

   THIS MEANS IF I WANT TO USE AIRFLOW DB (RECOMMENDED) REPLACE IN ENV USER AND PASSWORD AND DB NAME WITH THAT PROVIDED NOT ONLY ENV BUT ALSO FOR DBT . ALSO PORTS:5433:5432 MEANS DOCKER POSTGES MAP INTERNAL PORT 5432: TO 5433 SO ANY REQUEST MUST BE VIA THIS PORT 5433

WEEK2 DAY8-9
1. BOTO3 only know AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY . you must write those as it is
2. you use terraform output xxxx (specified in outputs.tf file) to print put important info for Config
3. always change schema and profile yml files whenver you use diffrent db . if use local db configuere them to work for that , if use docker db use configure them to work for that , if use AWS RDS db also do the same
4. to view data in AWS RDS use pgadmin or psql (no data in AWS console)


Week2 Day 10
1. 2 ways to deploy
      first: warp everythig to images push to ECR(elastic cintainer regsitry -> store docker images like docker hub) then ECS pulls image and deploys it 
      Second: use EC2 via SSH connection
2. SSH:secure shell -> imagine EC2 is like a virtual computer owned by amazon in their data centre (just as hardware comp) SSH is like a mouse and keyboard to access that computer from your place (like accessing that computer terminal and write commands to be executed from place you are sitting)    
3.  