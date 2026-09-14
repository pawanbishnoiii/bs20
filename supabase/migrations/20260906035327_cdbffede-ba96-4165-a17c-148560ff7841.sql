CREATE TABLE IF NOT EXISTS public.subject_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  stream text NOT NULL DEFAULT 'general',
  color text NOT NULL DEFAULT '#8B5CF6',
  chapters jsonb NOT NULL DEFAULT '[]'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name, stream)
);

GRANT SELECT ON public.subject_catalog TO authenticated;
GRANT ALL ON public.subject_catalog TO service_role;
ALTER TABLE public.subject_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Signed in users can browse the subject library" ON public.subject_catalog;
CREATE POLICY "Signed in users can browse the subject library"
  ON public.subject_catalog FOR SELECT TO authenticated USING (is_active);

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'has_role') THEN
    DROP POLICY IF EXISTS "Admins manage the subject library" ON public.subject_catalog;
    EXECUTE $policy$CREATE POLICY "Admins manage the subject library" ON public.subject_catalog FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'))$policy$;
  END IF;
END $$;

DO $$ BEGIN
  IF to_regprocedure('public.set_updated_at()') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'subject_catalog_updated_at') THEN
    CREATE TRIGGER subject_catalog_updated_at BEFORE UPDATE ON public.subject_catalog FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

INSERT INTO public.subject_catalog (name, stream, color, sort_order, chapters) VALUES
('Physics','science','#38BDF8',1,'["Units and Measurements","Motion in a Straight Line","Laws of Motion","Work, Energy and Power","Rotational Motion","Gravitation","Thermodynamics","Oscillations and Waves","Electrostatics","Current Electricity","Magnetism","Optics","Modern Physics"]'::jsonb),
('Chemistry','science','#A3E635',2,'["Some Basic Concepts of Chemistry","Atomic Structure","Chemical Bonding","States of Matter","Thermodynamics","Equilibrium","Redox Reactions","The p-Block Elements","Organic Chemistry Basics","Hydrocarbons","Alcohols and Ethers","Aldehydes and Ketones","Biomolecules"]'::jsonb),
('Mathematics','science','#8B5CF6',3,'["Sets and Functions","Trigonometry","Complex Numbers","Quadratic Equations","Sequences and Series","Straight Lines","Conic Sections","Limits and Derivatives","Differentiation","Integration","Differential Equations","Vectors","3D Geometry","Probability"]'::jsonb),
('Biology','science','#F472B6',4,'["The Living World","Cell: Structure and Function","Plant Physiology","Human Physiology","Reproduction","Genetics and Evolution","Human Health and Disease","Biotechnology","Ecology and Environment"]'::jsonb),
('English','general','#FB923C',5,'["Reading Comprehension","Grammar and Usage","Vocabulary","Writing Skills","Prose","Poetry","Literature Notes"]'::jsonb),
('Hindi','general','#FACC15',6,'["Gadya Khand","Padya Khand","Vyakaran","Nibandh Lekhan","Patra Lekhan","Apathit Gadyansh"]'::jsonb),
('Computer Science','science','#38BDF8',7,'["Computer Fundamentals","Programming Basics","Data Types and Operators","Control Flow","Functions","Arrays and Strings","Object Oriented Programming","Data Structures","Databases and SQL","Networking Basics"]'::jsonb),
('History','arts','#FB923C',8,'["Ancient India","Medieval India","Modern India","Revolt of 1857","Nationalist Movement","World Wars","Post Independence India"]'::jsonb),
('Geography','arts','#A3E635',9,'["Earth and Universe","Landforms","Climate","Water Resources","Natural Vegetation","Population","Agriculture","Industries","Maps and Practical Geography"]'::jsonb),
('Economics','commerce','#8B5CF6',10,'["Introduction to Economics","Consumer Behaviour","Producer Behaviour","Market Forms","National Income","Money and Banking","Government Budget","Balance of Payments","Indian Economy"]'::jsonb),
('Accountancy','commerce','#F472B6',11,'["Theory Base of Accounting","Journal and Ledger","Trial Balance","Depreciation","Financial Statements","Partnership Accounts","Company Accounts","Cash Flow Statement"]'::jsonb),
('Business Studies','commerce','#FACC15',12,'["Nature of Management","Principles of Management","Business Environment","Planning","Organising","Staffing","Directing","Controlling","Financial Management","Marketing Management"]'::jsonb),
('Political Science','arts','#38BDF8',13,'["Constitution","Rights and Duties","Executive","Legislature","Judiciary","Federalism","Political Theory","International Relations"]'::jsonb),
('General Knowledge','general','#A3E635',14,'["Current Affairs","Static GK","Indian Polity","Science and Technology","Sports","Awards and Honours"]'::jsonb),
('Reasoning','general','#FB923C',15,'["Series","Analogy","Coding-Decoding","Blood Relations","Direction Sense","Syllogism","Puzzles","Seating Arrangement","Data Sufficiency"]'::jsonb),
('Quantitative Aptitude','general','#8B5CF6',16,'["Number System","Percentage","Ratio and Proportion","Profit and Loss","Time and Work","Time Speed Distance","Averages","Simple and Compound Interest","Mensuration","Data Interpretation"]'::jsonb) ON CONFLICT (name, stream) DO NOTHING;